defmodule ConcurrenciaTest do
  use ExUnit.Case


  # en este enunciado se hace el proceso de asignar 50 litros de agua a dos necesidades que piden 30 y 25 al tiempo,
  # y revisa que solo una acepte, porque pues excede la cantidad disponible
  test "flujo de ejemplo: 30 y 25 litros al mismo tiempo cuando solo hay 50" do
    {:ok, _} = InventarioServer.registrar("RC1", "Agua", "agua", 50, "litros", "acopio_c1", "prueba")
    {:ok, _} = NecesidadesServer.registrar("agua", 30, "critica", "zona_c1", "necesidad_c1_a", "simon")
    {:ok, _} = NecesidadesServer.registrar("agua", 25, "alta", "zona_c1", "necesidad_c1_b", "samuel")

    resultados = al_mismo_tiempo([id_de("necesidad_c1_a"), id_de("necesidad_c1_b")], "RC1", "acopio_c1")

    assert Enum.count(resultados, &match?({:ok, _}, &1)) == 1
    assert Enum.count(resultados, &match?({:error, _}, &1)) == 1
    assert disponible("RC1", "acopio_c1") in [20, 25]
  end


  # tira 20 necesidades de 10 litros a la vez de un recurso que solo cuenta con 50, solo 5 se atenderan
  #y el inventario quedara en 0, no sigue dando en negativo
  test "muchas solicitudes simultaneas nunca superan el inventario" do
    {:ok, _} = InventarioServer.registrar("RC2", "Agua", "agua", 50, "litros", "acopio_c2", "prueba")

    ids =
      for n <- 1..20 do
        {:ok, _} = NecesidadesServer.registrar("agua", 10, "media", "zona_c2", "necesidad_c2_#{n}", "prueba")
        id_de("necesidad_c2_#{n}")
      end

    resultados = al_mismo_tiempo(ids, "RC2", "acopio_c2")

    assert Enum.count(resultados, &match?({:ok, _}, &1)) == 5
    assert disponible("RC2", "acopio_c2") == 0
  end

  # la misma necesidad se pide 5 veces al mismo tiempo: solo la primera recibe el recurso,
  # asi que solo se descuentan 10 litros y no 50.
  test "la misma necesidad no recibe recursos dos veces aunque se pida al mismo tiempo" do
    {:ok, _} = InventarioServer.registrar("RC3", "Agua", "agua", 100, "litros", "acopio_c3", "prueba")
    {:ok, _} = NecesidadesServer.registrar("agua", 10, "alta", "zona_c3", "necesidad_c3", "prueba")
    id = id_de("necesidad_c3")

    resultados = al_mismo_tiempo([id, id, id, id, id], "RC3", "acopio_c3")

    assert Enum.count(resultados, &match?({:ok, _}, &1)) == 1
    assert disponible("RC3", "acopio_c3") == 90
  end



  # lanza una tarea por cada id, todas al tiempo, y espera todas las respuestas
  defp al_mismo_tiempo(ids, codigo, ubicacion) do
    ids
    |> Enum.map(fn id -> Task.async(fn -> NecesidadesServer.asignar(id, codigo, ubicacion) end) end)
    |> Enum.map(&Task.await/1)
  end

  defp id_de(descripcion) do
    Enum.find(NecesidadesServer.listar(), &(&1.descripcion == descripcion)).id
  end

  defp disponible(codigo, ubicacion) do
    recurso = Enum.find(InventarioServer.listar(), &(&1.codigo == codigo))
    Recurso.disponible(recurso, ubicacion)
  end
end
