defmodule Zona do
  @moduledoc """
  en este modulo manejamos las zonas afectadas. las organizamos como un arbol, donde cada zona tiene sectores adentro y cada sector tiene sus puntos de atencion.

  cada zona, sector o punto tiene un codigo que no se repite (por ejemplo Z01), un nombre, el tipo ("zona", "sector" o "punto"), el nivel ("bajo", "medio", "alto" o "critico") y cuantas personas afectadas hay ahi.

  en `hijos` se guardan los sectores si es una zona, o los puntos si es un sector.

  como hay que recorrer el arbol, casi todas las funciones de este modulo son recursivas.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  defstruct codigo: "", nombre: "", tipo: "zona", nivel: "bajo", afectados: 0, hijos: []

  # le damos un numero a cada nivel para poder compararlos. entre mas alto, mas grave
  @niveles %{"bajo" => 1, "medio" => 2, "alto" => 3, "critico" => 4}

  @doc """
  esta funcion sirve para crear una zona, un sector o un punto, que empieza sin hijos.
  recibe el codigo, el nombre, el tipo, el nivel y los afectados.
  devuelve `{:ok, zona}` o `{:error, mensaje}` si falta el codigo, el nivel no existe o los afectados no son validos.
  """
  def crear(codigo, nombre, tipo, nivel, afectados) do
    cond do
      codigo == "" ->
        {:error, "Falta el codigo de la zona, sector o punto, por ejemplo Z01"}

      not Map.has_key?(@niveles, nivel) ->
        {:error, "El nivel tiene que ser critico, alto, medio o bajo"}

      not is_integer(afectados) or afectados < 0 ->
        {:error, "Los afectados tienen que ser un numero de 0 para arriba"}

      true ->
        {:ok, %Zona{codigo: codigo, nombre: nombre, tipo: tipo, nivel: nivel, afectados: afectados}}
    end
  end

  @doc """
  esta funcion revisa si un nodo puede tener debajo un hijo del tipo que se le pasa.
  los sectores solo pueden ir dentro de una zona y los puntos solo dentro de un sector.
  devuelve `true` o `false`.
  """
  def padre_valido?(padre, "sector"), do: padre.tipo == "zona"
  def padre_valido?(padre, "punto"), do: padre.tipo == "sector"
  def padre_valido?(_padre, _tipo), do: false

  @doc """
  esta funcion busca en todo el arbol la zona, sector o punto que tenga ese codigo. es recursiva.
  devuelve el nodo si lo encuentra o `nil` si no.
  """
  def buscar([], _codigo), do: nil
  def buscar([%Zona{codigo: codigo} = zona | _resto], codigo), do: zona

  def buscar([zona | resto], codigo) do
    case buscar(zona.hijos, codigo) do
      nil -> buscar(resto, codigo)
      encontrada -> encontrada
    end
  end

  @doc """
  esta funcion mete un hijo nuevo debajo del nodo que tiene el codigo del padre. es recursiva.
  devuelve la lista de zonas ya con el hijo agregado.
  """
  def agregar_hijo([], _codigo_padre, _hijo), do: []

  def agregar_hijo([zona | resto], codigo_padre, hijo) do
    actualizada =
      if zona.codigo == codigo_padre do
        %{zona | hijos: zona.hijos ++ [hijo]}
      else
        %{zona | hijos: agregar_hijo(zona.hijos, codigo_padre, hijo)}
      end

    [actualizada | agregar_hijo(resto, codigo_padre, hijo)]
  end

  @doc """
  esta funcion saca los totales de una zona juntando lo de todos sus sectores y puntos. es recursiva.
  devuelve un mapa con el total de afectados, cuantos sectores y puntos tiene y el nivel mas grave que se encontro.
  """
  def estadisticas(zona) do
    propias = %{
      afectados: zona.afectados,
      sectores: contar(zona.tipo, "sector"),
      puntos: contar(zona.tipo, "punto"),
      nivel_maximo: zona.nivel
    }

    sumar_hijos(zona.hijos, propias)
  end

  # le va sumando a lo acumulado las estadisticas de cada hijo
  defp sumar_hijos([], acumulado), do: acumulado

  defp sumar_hijos([hijo | resto], acumulado) do
    del_hijo = estadisticas(hijo)

    nuevo = %{
      afectados: acumulado.afectados + del_hijo.afectados,
      sectores: acumulado.sectores + del_hijo.sectores,
      puntos: acumulado.puntos + del_hijo.puntos,
      nivel_maximo: nivel_mayor(acumulado.nivel_maximo, del_hijo.nivel_maximo)
    }

    sumar_hijos(resto, nuevo)
  end

  @doc "esta funcion devuelve una lista con el codigo de la zona y los codigos de todo lo que tiene adentro. es recursiva."
  def codigos(zona), do: [zona.codigo | codigos_hijos(zona.hijos)]

  # junta los codigos de cada hijo y de todo lo que tenga debajo
  defp codigos_hijos([]), do: []
  defp codigos_hijos([hijo | resto]), do: codigos(hijo) ++ codigos_hijos(resto)

  @doc """
  esta funcion arma el texto del arbol de zonas para mostrarlo en pantalla. es recursiva.
  cada nivel del arbol se muestra un poco mas corrido a la derecha que el anterior.
  """
  def describir_arbol([], _sangria), do: ""

  def describir_arbol([zona | resto], sangria) do
    sangria <>
      "- [#{zona.tipo}] #{zona.codigo} #{zona.nombre} | nivel: #{zona.nivel} | afectados: #{zona.afectados}\n" <>
      describir_arbol(zona.hijos, sangria <> "    ") <>
      describir_arbol(resto, sangria)
  end

  # devuelve 1 si el tipo es el que estamos contando, y si no devuelve 0
  defp contar(tipo, tipo), do: 1
  defp contar(_tipo, _otro), do: 0

  # de los dos niveles que llegan, devuelve el que sea mas grave
  defp nivel_mayor(a, b) do
    if Map.get(@niveles, a) >= Map.get(@niveles, b), do: a, else: b
  end
end
