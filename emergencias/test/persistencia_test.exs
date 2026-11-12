defmodule PersistenciaTest do
  use ExUnit.Case

  # en este estamos guardando una zona con su sector y el punto, despues se lee de nuevo el archivo y revisa que el arbol quede igual
  test "las zonas se guardan y se recuperan con su arbol" do
    {:ok, _} = ZonasServer.registrar_zona("zona1", "Zona persistencia", "bajo", 10)
    {:ok, _} = ZonasServer.registrar_hijo("zona1", "sector", "sector1", "Sector", "medio", 5)
    {:ok, _} = ZonasServer.registrar_hijo("sector1", "punto", "punto1", "Punto", "alto", 2)

    assert Persistencia.cargar_zonas() == ZonasServer.listar()
  end

  # se registran 40 litros de agua en el acopio_p1, entonces tranfiere 15 litros al albergue_p1 y revisa que al leer salga 25 y 15
  test "los recursos se recuperan con lo que hay en cada ubicacion" do
    {:ok, _} = InventarioServer.registrar("RP1", "Agua", "agua", 40, "litros", "acopio1", "prueba")
    {:ok, _} = InventarioServer.transferir("RP1", "acopio1", "albergue1", 15, "prueba")

    recurso = Persistencia.cargar_recursos()["RP1"]
    assert recurso.existencias == %{"acopio1" => 25, "albergue1" => 15}
  end

  # Ssii una descripcion trae el separador "|", se guarda como "/" porque prevee que no dañe las columnas del archivo.
  test "un texto con el separador no dana el archivo" do
    {:ok, _} = NecesidadesServer.registrar("agua", 5, "baja", "zona2", "texto | con barra", "prueba")

    necesidad =
      Persistencia.cargar_necesidades()
      |> Map.values()
      |> Enum.find(&(&1.zona == "zona2"))

    assert necesidad.descripcion == "texto / con barra"
  end
end
