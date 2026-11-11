defmodule Recurso do
  @moduledoc """
  en este modulo manejamos los recursos del inventario (agua, alimentos, medicamentos y demas) y lleva la cuenta de cuanto hay de cada uno en cada lugar.

  cada recurso tiene un codigo (por ejemplo R01), un nombre, una categoria, que tiene que ser uno de los tipos de `Necesidad.tipos/0`, y la unidad en que se mide, como litros, cajas o kits.

  lo que hay se guarda en `existencias`, que es un mapa donde la llave es la ubicacion y el valor es la cantidad, por ejemplo `%{"centro_acopio_1" => 200, "A01" => 30}`.

  ninguna funcion de este modulo deja que una cantidad quede en negativo.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  defstruct codigo: "", nombre: "", categoria: "", unidad: "", existencias: %{}

  @doc """
  esta funcion sirve para crear un recurso nuevo con una cantidad inicial en una ubicacion.
  recibe el codigo, el nombre, la categoria, la cantidad, la unidad y la ubicacion.
  la cantidad puede ser 0 pero no negativa.
  devuelve `{:ok, recurso}` o `{:error, mensaje}` si falta el codigo, la categoria no existe o la cantidad no es valida.
  """
  def crear(codigo, nombre, categoria, cantidad, unidad, ubicacion) do
    cond do
      codigo == "" ->
        {:error, "Falta el codigo del recurso, por ejemplo R001"}

      categoria not in Necesidad.tipos() ->
        {:error, "Esa categoria no existe. Las que hay son: " <> Enum.join(Necesidad.tipos(), ", ")}

      not is_integer(cantidad) or cantidad < 0 ->
        {:error, "La cantidad tiene que ser un numero de 0 para arriba"}

      true ->
        {:ok,
         %Recurso{
           codigo: codigo,
           nombre: nombre,
           categoria: categoria,
           unidad: unidad,
           existencias: %{ubicacion => cantidad}
         }}
    end
  end

  @doc "esta funcion devuelve cuanto hay del recurso en una ubicacion. si en ese lugar no hay nada devuelve 0."
  def disponible(recurso, ubicacion), do: Map.get(recurso.existencias, ubicacion, 0)

  @doc "esta funcion suma lo que hay del recurso en todas las ubicaciones y devuelve el total."
  def total(recurso), do: Enum.sum(Map.values(recurso.existencias))

  @doc """
  esta funcion sirve para agregar unidades del recurso en una ubicacion, como una entrada al inventario.
  la cantidad tiene que ser un numero mayor que 0.
  devuelve `{:ok, recurso_actualizado}` o `{:error, mensaje}`.
  """
  def agregar(recurso, ubicacion, cantidad) do
    if is_integer(cantidad) and cantidad > 0 do
      existencias = Map.update(recurso.existencias, ubicacion, cantidad, fn actual -> actual + cantidad end)
      {:ok, %{recurso | existencias: existencias}}
    else
      {:error, "La cantidad tiene que ser un numero mayor que 0"}
    end
  end

  @doc """
  esta funcion sirve para sacar unidades del recurso de una ubicacion, como una salida del inventario.
  si no hay suficiente no saca nada, ni siquiera una parte, y asi nunca quedan cantidades negativas.
  devuelve `{:ok, recurso_actualizado}` o `{:error, mensaje}`.
  """
  def retirar(recurso, ubicacion, cantidad) do
    hay = disponible(recurso, ubicacion)

    cond do
      not is_integer(cantidad) or cantidad <= 0 ->
        {:error, "La cantidad tiene que ser un numero mayor que 0"}

      cantidad > hay ->
        {:error,
         "No hay suficiente #{recurso.codigo} en #{ubicacion}, se pidieron #{cantidad} #{recurso.unidad} y solo hay #{hay}"}

      true ->
        {:ok, %{recurso | existencias: Map.put(recurso.existencias, ubicacion, hay - cantidad)}}
    end
  end

  @doc """
  esta funcion sirve para pasar unidades del recurso de una ubicacion a otra.
  el origen y el destino no pueden ser el mismo lugar, y en el origen tiene que haber suficiente.
  devuelve `{:ok, recurso_actualizado}` o `{:error, mensaje}`.
  """
  def transferir(recurso, origen, destino, cantidad) do
    if origen == destino do
      {:error, "El origen y el destino tienen que ser lugares distintos"}
    else
      case retirar(recurso, origen, cantidad) do
        {:ok, sin_origen} -> agregar(sin_origen, destino, cantidad)
        error -> error
      end
    end
  end

  @doc """
  esta funcion saca del inventario lo que se va a usar para atender una necesidad.
  el recurso tiene que ser de la misma categoria que la necesidad. la unica excepcion son las necesidades de tipo "otra", que pueden recibir cualquier recurso.
  devuelve `{:ok, recurso_actualizado}` o `{:error, mensaje}`.
  """
  def asignar(recurso, ubicacion, cantidad, tipo_necesidad) do
    if recurso.categoria == tipo_necesidad or tipo_necesidad == "otra" do
      retirar(recurso, ubicacion, cantidad)
    else
      {:error, "El recurso #{recurso.codigo} es de #{recurso.categoria} y la necesidad es de #{tipo_necesidad}, no se puede asignar"}
    end
  end

  @doc "esta funcion arma una linea de texto con el total del recurso y lo que hay en cada ubicacion, para mostrarla en pantalla."
  def describir(recurso) do
    existencias =
      Enum.map_join(recurso.existencias, ", ", fn {ubicacion, cantidad} -> "#{ubicacion}: #{cantidad}" end)

    "#{recurso.codigo} | #{recurso.nombre} (#{recurso.categoria}) | total: #{total(recurso)} #{recurso.unidad} | #{existencias}"
  end
end
