defmodule DominioTest do
  use ExUnit.Case

  #esta revisando que la linea escrita se separe en palabras, y si esta entre comillas quede junto
  test "el parser separa por espacios y respeta las comillas" do
    assert Parser.tokenizar(~s(registrar_albergue A01 "Albergue Norte" norte 150)) ==
             ["registrar_albergue", "A01", "Albergue Norte", "norte", "150"]
  end

  # esta pando por un filtro de clave valor, y mira si se lee correctamente, aparte de que si la clave no existe, da error
  test "los filtros se convierten en una lista de palabras clave" do
    assert Parser.filtros(["zona=centro", "prioridad=critica"], %{"zona" => :zona, "prioridad" => :prioridad}) ==
             {:ok, [zona: "centro", prioridad: "critica"]}

    assert {:error, _} = Parser.filtros(["color=rojo"], %{"zona" => :zona})
  end


  # arma el arbol con una zona, un sector y un punto, despues revisa las funciones recursivas: buscar, sacar los codigos
  # y sumar las estadisticas de todo lo que hay adentro.
  test "las estadisticas de una zona suman sus sectores y puntos" do
    {:ok, zona} = Zona.crear("centro", "Centro", "zona", "medio", 100)
    {:ok, sector} = Zona.crear("s1", "Sector 1", "sector", "alto", 50)
    {:ok, punto} = Zona.crear("p1", "Punto 1", "punto", "critico", 20)

    arbol =
      [zona]
      |> Zona.agregar_hijo("centro", sector)
      |> Zona.agregar_hijo("s1", punto)

    [raiz] = arbol
    assert Zona.buscar(arbol, "p1").nombre == "Punto 1"
    assert Zona.codigos(raiz) == ["centro", "s1", "p1"]
    assert Zona.estadisticas(raiz) == %{afectados: 170, sectores: 1, puntos: 1, nivel_maximo: "critico"}
  end


  # revisa que las necesidades queden de forma ordenada de la mas urgente a la menos urgente.
  test "las necesidades se ordenan por prioridad" do
    {:ok, n1} = Necesidad.crear("N001", "agua", 10, "baja", "z", "d", "u")
    {:ok, n2} = Necesidad.crear("N002", "agua", 10, "critica", "z", "d", "u")
    {:ok, n3} = Necesidad.crear("N003", "agua", 10, "media", "z", "d", "u")

    ordenadas = Necesidad.ordenar_por_prioridad([n1, n2, n3])
    assert Enum.map(ordenadas, & &1.id) == ["N002", "N003", "N001"]
  end


  # hace el proceso de llevar una necesidad desde creada hasta atendida y revisa que despues ya no pueda cambiar de estado.
  test "una necesidad atendida no se cierra dos veces ni vuelve a recibir recursos" do
    {:ok, n} = Necesidad.crear("N001", "agua", 10, "alta", "z", "d", "u")
    {:ok, n} = Necesidad.cambiar_estado(n, "asignada")
    {:ok, n} = Necesidad.cambiar_estado(n, "en_atencion")
    {:ok, n} = Necesidad.cambiar_estado(n, "atendida")

    assert {:error, _} = Necesidad.cambiar_estado(n, "atendida")
    assert {:error, _} = Necesidad.cambiar_estado(n, "asignada")
  end

  # Revisa que no se pueda sacar mas de lo que hay ni crear un recurso con cantidad negativa.
  # revisa que no se pueda sacar de donde no hay y que no se creen recursos con cantidades negativas.
  test "un recurso nunca queda con cantidades negativas" do
    {:ok, r} = Recurso.crear("R1", "Agua", "agua", 50, "litros", "c1")
    assert {:error, _} = Recurso.retirar(r, "c1", 51)

    {:ok, r} = Recurso.retirar(r, "c1", 50)
    assert Recurso.disponible(r, "c1") == 0
    assert {:error, _} = Recurso.crear("R2", "Agua", "agua", -5, "litros", "c1")
  end

  # pasa 30 de 50 de un centro a otro y revisa que el original quede con 20, el destino debe de tener 30 y el total siue siendo de 50
  test "transferir mueve unidades entre centros" do
    {:ok, r} = Recurso.crear("R1", "Agua", "agua", 50, "litros", "c1")
    {:ok, r} = Recurso.transferir(r, "c1", "A2", 30)

    assert Recurso.disponible(r, "c1") == 20
    assert Recurso.disponible(r, "A2") == 30
    assert Recurso.total(r) == 50
  end

  # esta revisa que cada tipo de usuario tenga los permisos que le corresponden y que nadie pueda registrarse por si mismo como coordinador.
  test "los permisos dependen del tipo de usuario" do
    assert Usuario.puede?("coordinador", "asignar_recurso")
    refute Usuario.puede?("ciudadano", "asignar_recurso")
    assert Usuario.puede?("administrador", "crear_usuario")
    assert {:error, _} = Usuario.validar_autoregistro("coordinador")
  end
end
