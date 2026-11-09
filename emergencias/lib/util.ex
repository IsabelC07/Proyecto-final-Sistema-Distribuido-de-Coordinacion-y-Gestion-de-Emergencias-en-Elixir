defmodule Util do
  @moduledoc """
  funciones varias de apoyo que usan varios modulos: para mostrar texto en la pantalla,
  lee lo que recibe del usuario, obtiene la fecha del dia y genera ids
  creimos mejor crear uno nuevo a diferencia del que teneniamos en clase porque este se ajusta mas a lo que necesitabamos y
  vamos a usar mas recurrentemente, en su lugar, el otro nos generaria mas cambios en la edicion (por lo menos esa era nuesta
  forma de pensar cuando lo generammos)

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  @doc "muesta mensaje en pantalla."
  def mostrar_mensaje(mensaje) do
    mensaje
    |> IO.puts()
  end

  @doc "muestra error en la salida del error."
  def mostrar_error(mensaje) do
    IO.puts(:standard_error, mensaje)
  end

  @doc """
  muestra un mensaje, espera a que el usuario ingrese algo y devuelve el texto escrito sin los espacios ni saltos de linea
  al inicio o al final
  """
  def ingresar(mensaje, :texto) do
    mensaje
    |> IO.gets()
    |> String.trim()
  end

  @doc """
  devuelve la fecha y la hora en ese moemnto como texto, con este formato de ejemplo `2026-03-15 11:46:41`
  """
  def fecha_actual do
    NaiveDateTime.local_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
  end

  @doc """
  esta generando un id uniendo un prefijo con un numero de 3 cifras
  aqui dare un ejemplo: `generar_id("N", 7)` me estaria devolviendo `"N007"`
  """
  def generar_id(prefijo, numero) do
    prefijo <> String.pad_leading(Integer.to_string(numero), 3, "0")
  end
end
