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


  # esta revisa que cada tipo de usuario tenga los permisos que le corresponden y que nadie pueda registrarse por si mismo como coordinador.
  test "los permisos dependen del tipo de usuario" do
    assert Usuario.puede?("coordinador", "asignar_recurso")
    refute Usuario.puede?("ciudadano", "asignar_recurso")
    assert Usuario.puede?("administrador", "crear_usuario")
    assert {:error, _} = Usuario.validar_autoregistro("coordinador")
  end
end
