defmodule Albergue do
  @moduledoc """
  en este modulo manejamos los albergues, que son los lugares a donde llegan las personas afectadas mientras se resuelve su situacion.

  cada albergue tiene un codigo (por ejemplo A01), un nombre, la zona donde queda y la capacidad, que es cuantas personas caben.

  las personas que estan adentro se guardan en un MapSet con sus documentos, asi una misma persona no puede quedar dos veces.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  defstruct codigo: "", nombre: "", zona: "", capacidad: 0, personas: MapSet.new()

  @doc """
  esta funcion sirve para crear un albergue nuevo, que empieza sin nadie adentro.
  recibe el codigo, el nombre, la zona y la capacidad.
  devuelve `{:ok, albergue}` si sale bien o `{:error, mensaje}` si falta el codigo o la capacidad no es valida.
  """
  def crear(codigo, nombre, zona, capacidad) do
    cond do
      codigo == "" ->
        {:error, "Falta el codigo del albergue, por ejemplo A01"}

      not is_integer(capacidad) or capacidad <= 0 ->
        {:error, "La capacidad tiene que ser un numero mayor que 0"}

      true ->
        {:ok, %Albergue{codigo: codigo, nombre: nombre, zona: zona, capacidad: capacidad}}
    end
  end

  @doc "esta funcion devuelve cuantas personas hay adentro del albergue en este momento."
  def ocupacion(albergue), do: MapSet.size(albergue.personas)

  @doc "esta funcion devuelve cuantos cupos libres le quedan al albergue."
  def cupos(albergue), do: albergue.capacidad - ocupacion(albergue)

  @doc "esta funcion devuelve el porcentaje de ocupacion del albergue, como un numero entero de 0 a 100."
  def porcentaje(albergue), do: div(ocupacion(albergue) * 100, albergue.capacidad)

  @doc """
  esta funcion sirve para que una persona entre al albergue.
  recibe el albergue y el documento de la persona.
  no deja entrar a la persona si ya estaba adentro o si el albergue esta lleno.
  devuelve `{:ok, albergue_actualizado}` o `{:error, mensaje}`.
  """
  def ingresar(albergue, documento) do
    cond do
      MapSet.member?(albergue.personas, documento) ->
        {:error, "La persona #{documento} ya esta en el albergue #{albergue.codigo}"}

      ocupacion(albergue) >= albergue.capacidad ->
        {:error, "El albergue #{albergue.codigo} esta lleno, solo caben #{albergue.capacidad} personas"}

      true ->
        {:ok, %{albergue | personas: MapSet.put(albergue.personas, documento)}}
    end
  end

  @doc """
  esta funcion sirve para sacar a una persona del albergue.
  recibe el albergue y el documento de la persona.
  si la persona no estaba adentro devuelve un error.
  devuelve `{:ok, albergue_actualizado}` o `{:error, mensaje}`.
  """
  def retirar(albergue, documento) do
    if MapSet.member?(albergue.personas, documento) do
      {:ok, %{albergue | personas: MapSet.delete(albergue.personas, documento)}}
    else
      {:error, "La persona #{documento} no esta en el albergue #{albergue.codigo}"}
    end
  end

  @doc "esta funcion arma una linea de texto con los datos del albergue y que tan lleno esta, para mostrarla en pantalla."
  def describir(a) do
    "#{a.codigo} | #{a.nombre} | zona: #{a.zona} | ocupacion: #{ocupacion(a)}/#{a.capacidad} " <>
      "(#{porcentaje(a)}%) | cupos: #{cupos(a)}"
  end
end
