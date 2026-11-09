defmodule PersistenciaTest do
  use ExUnit.Case

  # en este estamos guardando una zona con su sector y el punto, despues se lee de nuevo el archivo y revisa que el arbol quede igual
  test "las zonas se guardan y se recuperan con su arbol" do
    {:ok, _} = ZonasServer.registrar_zona("zona1", "Zona persistencia", "bajo", 10)
    {:ok, _} = ZonasServer.registrar_hijo("zona1", "sector", "sector1", "Sector", "medio", 5)
    {:ok, _} = ZonasServer.registrar_hijo("sector1", "punto", "punto1", "Punto", "alto", 2)

    assert Persistencia.cargar_zonas() == ZonasServer.listar()
  end
end
