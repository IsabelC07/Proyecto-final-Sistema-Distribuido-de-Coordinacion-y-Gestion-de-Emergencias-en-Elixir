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


  # esta revisa que cada tipo de usuario tenga los permisos que le corresponden y que nadie pueda registrarse por si mismo como coordinador.
  test "los permisos dependen del tipo de usuario" do
    assert Usuario.puede?("coordinador", "asignar_recurso")
    refute Usuario.puede?("ciudadano", "asignar_recurso")
    assert Usuario.puede?("administrador", "crear_usuario")
    assert {:error, _} = Usuario.validar_autoregistro("coordinador")
  end
end
