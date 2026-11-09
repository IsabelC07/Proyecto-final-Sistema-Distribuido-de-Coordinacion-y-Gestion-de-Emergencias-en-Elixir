defmodule Parser do
  @moduledoc """

  Convierte el texto que escribe el usuario en datos entendibles por nuesto sistemaL: separa la linea en palabras, lee filtros
   del tipo clave valor y convierte texto en numeros enteros

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  @doc """
  separa una linea en palabras. lo que tiene comillas va en una solaa palabra

  por ejemplo: la línea `registrar_albergue A01 "Albergue Norte" norte 234` da
  `["registrar_albergue", "A01", "Albergue Norte", "norte", "234"]`.
  """
  def tokenizar(linea), do: tokenizar(String.graphemes(linea), "", [], false)

  # es un recorrido de lineea letra por letra
  # actual: palabra que se esta armando; palabras: las ya terminadas (de forma invertida o al revez);
  # en las comillas, es true si se esta dentro de unas comillas (los espacios no lo separan)

  defp tokenizar([], "", palabras, _en_comillas), do: Enum.reverse(palabras)
  defp tokenizar([], actual, palabras, _en_comillas), do: Enum.reverse([actual | palabras])
  defp tokenizar(["\"" | resto], actual, palabras, false), do: tokenizar(resto, actual, palabras, true)
  defp tokenizar(["\"" | resto], actual, palabras, true), do: tokenizar(resto, "", [actual | palabras], false)
  defp tokenizar([" " | resto], "", palabras, false), do: tokenizar(resto, "", palabras, false)
  defp tokenizar([" " | resto], actual, palabras, false), do: tokenizar(resto, "", [actual | palabras], false)
  defp tokenizar([letra | resto], actual, palabras, en_comillas), do: tokenizar(resto, actual <> letra, palabras, en_comillas)

  @doc """

  convierte las palabras con la forma de clave valor en una lista de filtros (recursiva)

  permitidos es un mapa con las claves que acepta el comando,
  dando un ejemplo es =  `%{"zona" => :zona}`

  y un ejemplo mas concreto es: `["zona=centro", "prioridad=critica"]` da
  `{:ok, [zona: "centro", prioridad: "critica"]}`.
  si por algun cazo una clave no esta permitida da `{:error, mensaje}`.
  """
  def filtros(palabras, permitidos), do: filtros(palabras, permitidos, [])

  # Recursiva: va guardando cada filtro valido en acumulado
  defp filtros([], _permitidos, acumulado), do: {:ok, Enum.reverse(acumulado)}

  defp filtros([palabra | resto], permitidos, acumulado) do
    case String.split(palabra, "=", parts: 2) do
      [clave, valor] when is_map_key(permitidos, clave) ->
        filtros(resto, permitidos, [{Map.get(permitidos, clave), valor} | acumulado])

      _ ->
        {:error, "Filtro invalido: #{palabra}. Filtros permitidos: " <> Enum.join(Map.keys(permitidos), ", ")}
    end
  end

  @doc """
  convierte texto en numero entero
  retorna el numero o nil si el texto no es un entero, por ejemplo: 12a
  """
  def entero(texto) do
    case Integer.parse(texto) do
      {numero, ""} -> numero
      _ -> nil
    end
  end
end
