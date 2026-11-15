defmodule Mascota do
  @moduledoc """
  en este modulo manejamos los reportes de mascotas, tanto las que se perdieron como las que alguien encontro durante la emergencia.

  cada reporte tiene un id (por ejemplo MA001), si es "perdida" o "encontrada", los datos de la mascota (especie, nombre, color, tamano y caracteristicas), la zona y un contacto. los datos de la mascota se guardan en minuscula para que sea mas facil compararlos.

  el estado empieza en "activa", puede pasar a "posible_coincidencia" y al final queda "resuelta". cuando se confirma que dos reportes son la misma mascota, cada uno guarda el id del otro en `coincidencia`.

  tambien compara las perdidas con las encontradas y les da un puntaje, para saber cuales se parecen y ayudar a que la mascota vuelva con su familia.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  defstruct id: "",
            tipo: "",
            especie: "",
            nombre: "",
            color: "",
            tamano: "",
            zona: "",
            contacto: "",
            caracteristicas: "",
            estado: "activa",
            coincidencia: ""

  @tipos ["perdida", "encontrada"]
  @tamanos ["pequena", "mediana", "grande"]

  # si dos reportes sacan este puntaje o mas (de 100), los tomamos como una posible coincidencia
  @umbral 60

  @doc """
  esta funcion sirve para crear un reporte de mascota nuevo, que empieza en estado "activa".
  recibe el id, el tipo, la especie, el nombre, el color, el tamano, la zona, el contacto y las caracteristicas.
  si no saben el nombre de la mascota, se guarda como "desconocido".
  devuelve `{:ok, mascota}` o `{:error, mensaje}` si el tipo o el tamano no son validos, o si falta la especie o el contacto.
  """
  def crear(id, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas) do
    cond do
      tipo not in @tipos ->
        {:error, "El tipo tiene que ser perdida o encontrada"}

      tamano not in @tamanos ->
        {:error, "El tamano tiene que ser pequena, mediana o grande"}

      especie == "" or contacto == "" ->
        {:error, "Falta la especie de la mascota o el contacto"}

      true ->
        {:ok,
         %Mascota{
           id: id,
           tipo: tipo,
           especie: String.downcase(especie),
           nombre: normalizar_nombre(nombre),
           color: String.downcase(color),
           tamano: tamano,
           zona: zona,
           contacto: contacto,
           caracteristicas: String.downcase(caracteristicas)
         }}
    end
  end

  @doc """
  esta funcion le da un puntaje de 0 a 100 a una mascota perdida comparada con una encontrada, segun que tanto se parecen.
  si la especie es distinta da 0, porque no puede ser el mismo animal.
  si no, suma 30 si estan en la misma zona, 25 si son del mismo color, 20 si tienen el mismo tamano y 15 si tienen el mismo nombre (solo cuando los dos reportes tienen nombre).
  por las caracteristicas que tengan en comun suma maximo 10 puntos mas.
  """
  def puntaje(perdida, encontrada) do
    if perdida.especie != encontrada.especie do
      0
    else
      igual(perdida.zona, encontrada.zona, 30) +
        igual(perdida.color, encontrada.color, 25) +
        igual(perdida.tamano, encontrada.tamano, 20) +
        puntaje_nombre(perdida.nombre, encontrada.nombre) +
        puntaje_caracteristicas(perdida.caracteristicas, encontrada.caracteristicas)
    end
  end

  @doc """
  esta funcion compara cada mascota perdida con todas las encontradas. es recursiva.
  devuelve una lista de tuplas `{id_perdida, id_encontrada, puntaje}`, pero solo con las parejas que sacaron 60 puntos o mas.
  """
  def coincidencias([], _encontradas), do: []

  def coincidencias([perdida | resto], encontradas),
    do: comparar(perdida, encontradas) ++ coincidencias(resto, encontradas)

  # compara una mascota perdida con cada una de las encontradas y guarda la tupla cuando el puntaje llega al umbral
  defp comparar(_perdida, []), do: []

  defp comparar(perdida, [encontrada | resto]) do
    puntos = puntaje(perdida, encontrada)

    if puntos >= @umbral do
      [{perdida.id, encontrada.id, puntos} | comparar(perdida, resto)]
    else
      comparar(perdida, resto)
    end
  end

  @doc """
  esta funcion pasa el reporte a "posible_coincidencia", pero solo si todavia esta "activa".
  si el reporte esta en otro estado lo deja como estaba.
  """
  def marcar_posible(%Mascota{estado: "activa"} = mascota), do: %{mascota | estado: "posible_coincidencia"}
  def marcar_posible(mascota), do: mascota

  @doc """
  esta funcion sirve para confirmar que la mascota perdida y la encontrada son el mismo animal.
  recibe primero el reporte de la perdida y despues el de la encontrada.
  cuando se confirma, los dos reportes quedan "resuelta" y cada uno guarda el id del otro.
  devuelve `{:ok, perdida, encontrada}` o `{:error, mensaje}` si falta algun reporte, si vienen en el orden equivocado, si alguno ya estaba resuelto o si son de especies distintas.
  """
  def confirmar(nil, _encontrada), do: {:error, "No existe ningun reporte de mascota perdida con ese id"}
  def confirmar(_perdida, nil), do: {:error, "No existe ningun reporte de mascota encontrada con ese id"}

  def confirmar(perdida, encontrada) do
    cond do
      perdida.tipo != "perdida" or encontrada.tipo != "encontrada" ->
        {:error, "Primero va el reporte de la mascota perdida y despues el de la encontrada"}

      perdida.estado == "resuelta" or encontrada.estado == "resuelta" ->
        {:error, "Uno de los dos reportes ya estaba resuelto"}

      perdida.especie != encontrada.especie ->
        {:error, "No puede ser la misma mascota porque son de especies distintas"}

      true ->
        {:ok, %{perdida | estado: "resuelta", coincidencia: encontrada.id},
         %{encontrada | estado: "resuelta", coincidencia: perdida.id}}
    end
  end

  @doc "esta funcion arma una linea de texto con todos los datos del reporte, para mostrarla en pantalla."
  def describir(m) do
    coincidencia = if m.coincidencia == "", do: "", else: " | coincide con: #{m.coincidencia}"

    "#{m.id} | #{m.tipo} | #{m.especie} | nombre: #{m.nombre} | #{m.color} | #{m.tamano} | zona: #{m.zona} | " <>
      "contacto: #{m.contacto} | estado: #{m.estado} | #{m.caracteristicas}#{coincidencia}"
  end

  # deja el nombre en minuscula, y si no escribieron nada lo guarda como "desconocido"
  defp normalizar_nombre(nombre) do
    nombre = String.downcase(nombre)
    if nombre == "", do: "desconocido", else: nombre
  end

  # si los dos valores son iguales devuelve los puntos, y si no devuelve 0
  defp igual(a, a, puntos), do: puntos
  defp igual(_a, _b, _puntos), do: 0

  # da 15 puntos cuando el nombre es el mismo. si son distintos o alguno es "desconocido" da 0, porque asi no sirve para comparar
  defp puntaje_nombre("desconocido", _otro), do: 0
  defp puntaje_nombre(_otro, "desconocido"), do: 0
  defp puntaje_nombre(nombre, nombre), do: 15
  defp puntaje_nombre(_a, _b), do: 0

  # da maximo 10 puntos. separa las caracteristicas en palabras, las mete en MapSet y mira cuantas comparten frente al total de palabras distintas
  defp puntaje_caracteristicas(a, b) do
    palabras_a = MapSet.new(String.split(a))
    palabras_b = MapSet.new(String.split(b))
    total = MapSet.size(MapSet.union(palabras_a, palabras_b))

    if total == 0 do
      0
    else
      comunes = MapSet.size(MapSet.intersection(palabras_a, palabras_b))
      round(comunes * 10 / total)
    end
  end
end
