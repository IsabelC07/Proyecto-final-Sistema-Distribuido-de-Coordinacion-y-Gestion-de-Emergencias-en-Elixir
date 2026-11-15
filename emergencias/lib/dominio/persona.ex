defmodule Persona do
  @moduledoc """
  en este modulo manejamos a las personas que se reportan durante la emergencia, ya sea porque estan desaparecidas, porque las encontraron o porque llegaron a un albergue.

  de cada persona se guarda un id (por ejemplo P001), el documento, que no se puede repetir, el nombre, la edad, la zona y el estado en que esta.

  tambien se guarda un historial con todos los cambios de estado. cada cambio queda como la tupla `{fecha, estado_anterior, estado_nuevo}`.

  los estados son sin_informacion, reportada, localizada, trasladada, en_albergue y reunificada. cuando llega a reunificada ya no puede cambiar mas, porque es el ultimo estado.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  defstruct id: "", documento: "", nombre: "", edad: 0, zona: "", estado: "sin_informacion", historial: []

  # una persona no puede empezar en "en_albergue", a ese estado solo se llega con registrar_ingreso
  @estados_iniciales ["sin_informacion", "reportada", "localizada"]

  # para cada estado, la lista de estados a los que puede pasar la persona
  @transiciones %{
    "sin_informacion" => ["reportada", "localizada", "en_albergue"],
    "reportada" => ["localizada", "en_albergue"],
    "localizada" => ["trasladada", "en_albergue", "reunificada"],
    "trasladada" => ["en_albergue", "reunificada"],
    "en_albergue" => ["trasladada", "reunificada"],
    "reunificada" => []
  }

  @doc """
  esta funcion sirve para crear el reporte de una persona y de una vez guarda el primer registro en su historial.
  recibe el id, el documento, el nombre, la edad, la zona y el estado con el que empieza.
  el estado inicial solo puede ser sin_informacion, reportada o localizada.
  devuelve `{:ok, persona}` o `{:error, mensaje}` si falta el documento o el nombre, si la edad no esta entre 0 y 120 o si el estado no se puede usar.
  """
  def crear(id, documento, nombre, edad, zona, estado) do
    cond do
      documento == "" or nombre == "" ->
        {:error, "Falta el documento o el nombre de la persona"}

      not is_integer(edad) or edad < 0 or edad > 120 ->
        {:error, "La edad tiene que ser un numero entre 0 y 120"}

      estado not in @estados_iniciales ->
        {:error, "La persona no puede empezar con ese estado. Los que hay son: " <> Enum.join(@estados_iniciales, ", ")}

      true ->
        {:ok,
         %Persona{
           id: id,
           documento: documento,
           nombre: nombre,
           edad: edad,
           zona: zona,
           estado: estado,
           historial: [{Util.fecha_actual(), "-", estado}]
         }}
    end
  end

  @doc """
  esta funcion le cambia el estado a la persona y anota ese cambio en su historial.
  el parametro `manual` llega en `true` cuando el cambio lo hace un usuario con el comando actualizar_persona.
  en ese caso no deja meter ni sacar a nadie de un albergue, porque para eso estan registrar_ingreso y registrar_salida. asi lo que dice el albergue siempre cuadra con el estado de cada persona.
  devuelve `{:ok, persona_actualizada}` o `{:error, mensaje}`.
  """
  def cambiar_estado(_persona, "en_albergue", true),
    do: {:error, "Para meter a la persona en un albergue hay que usar el comando registrar_ingreso"}

  def cambiar_estado(%Persona{estado: "en_albergue"}, _nuevo, true),
    do: {:error, "La persona sigue en un albergue, primero hay que sacarla con registrar_salida"}

  def cambiar_estado(persona, nuevo, _manual) do
    if nuevo in Map.get(@transiciones, persona.estado, []) do
      cambio = {Util.fecha_actual(), persona.estado, nuevo}
      {:ok, %{persona | estado: nuevo, historial: persona.historial ++ [cambio]}}
    else
      {:error, "La persona #{persona.documento} esta #{persona.estado} y no puede pasar a #{nuevo}"}
    end
  end

  @doc "esta funcion arma una linea de texto con los datos de la persona, para mostrarla en pantalla."
  def describir(p) do
    "#{p.id} | documento: #{p.documento} | #{p.nombre} | edad: #{p.edad} | zona: #{p.zona} | estado: #{p.estado}"
  end

  @doc "esta funcion arma el texto de un cambio del historial, que se ve asi: `fecha: reportada -> localizada`."
  def describir_cambio({fecha, anterior, nuevo}), do: "  #{fecha}: #{anterior} -> #{nuevo}"
end
