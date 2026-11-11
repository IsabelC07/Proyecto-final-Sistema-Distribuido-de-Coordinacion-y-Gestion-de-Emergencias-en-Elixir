defmodule Necesidad do
  @moduledoc """
  en este modulo manejamos las necesidades que se reportan en una zona, como falta de agua, de alimentos, de medicamentos o que se necesite un rescate.

  de cada necesidad se guarda que se necesita, cuanto, que tan urgente es ("critica", "alta", "media" o "baja"), donde se necesita, quien la reporto y la fecha. si se le asigna un recurso, tambien queda anotado cual fue y de donde salio.

  los estados van en este orden: pendiente, asignada, en_atencion y atendida. mientras este pendiente tambien se puede cancelar.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  defstruct id: "",
            tipo: "",
            cantidad: 0,
            prioridad: "",
            zona: "",
            descripcion: "",
            responsable: "",
            estado: "pendiente",
            recurso: "",
            fecha: ""

  @tipos ["agua", "alimentos", "medicamentos", "primeros_auxilios", "refugio", "transporte", "rescate", "otra"]

  # entre mas bajo el numero, antes se atiende la necesidad
  @prioridades %{"critica" => 1, "alta" => 2, "media" => 3, "baja" => 4}

  # para cada estado, la lista de estados a los que se puede pasar
  @transiciones %{
    "pendiente" => ["asignada", "cancelada"],
    "asignada" => ["en_atencion"],
    "en_atencion" => ["atendida"],
    "atendida" => [],
    "cancelada" => []
  }

  @doc """
  esta funcion devuelve la lista con los tipos de necesidad que se aceptan.
  esta misma lista la usamos como categorias para los recursos.
  """
  def tipos, do: @tipos

  @doc """
  esta funcion sirve para crear una necesidad nueva, que empieza en "pendiente" y con la fecha del momento en que se reporta.
  recibe el id, el tipo, la cantidad, la prioridad, la zona, la descripcion y el responsable.
  devuelve `{:ok, necesidad}` o `{:error, mensaje}` si el tipo no existe, la cantidad no es valida o la prioridad no existe.
  """
  def crear(id, tipo, cantidad, prioridad, zona, descripcion, responsable) do
    cond do
      tipo not in @tipos ->
        {:error, "Ese tipo de necesidad no existe. Los que hay son: " <> Enum.join(@tipos, ", ")}

      not is_integer(cantidad) or cantidad <= 0 ->
        {:error, "La cantidad tiene que ser un numero mayor que 0"}

      not Map.has_key?(@prioridades, prioridad) ->
        {:error, "La prioridad tiene que ser critica, alta, media o baja"}

      true ->
        {:ok,
         %Necesidad{
           id: id,
           tipo: tipo,
           cantidad: cantidad,
           prioridad: prioridad,
           zona: zona,
           descripcion: descripcion,
           responsable: responsable,
           fecha: Util.fecha_actual()
         }}
    end
  end

  @doc """
  esta funcion cambia la necesidad a otro estado, siempre que ese cambio se pueda hacer.
  por ejemplo, si la necesidad ya esta "atendida" no se le puede cambiar el estado.
  devuelve `{:ok, necesidad_actualizada}` o `{:error, mensaje}`.
  """
  def cambiar_estado(necesidad, nuevo_estado) do
    if nuevo_estado in Map.get(@transiciones, necesidad.estado, []) do
      {:ok, %{necesidad | estado: nuevo_estado}}
    else
      {:error, "La necesidad #{necesidad.id} esta #{necesidad.estado} y no puede pasar a #{nuevo_estado}"}
    end
  end

  @doc """
  esta funcion ordena la lista de necesidades para que queden de primeras las mas urgentes (critica, alta, media y al final baja).
  es recursiva y usa el ordenamiento por insercion.
  """
  def ordenar_por_prioridad([]), do: []

  def ordenar_por_prioridad([necesidad | resto]),
    do: insertar(necesidad, ordenar_por_prioridad(resto))

  # mete la necesidad en la posicion que le toca dentro de una lista que ya esta ordenada
  defp insertar(necesidad, []), do: [necesidad]

  defp insertar(necesidad, [primera | resto] = lista) do
    if valor_prioridad(necesidad) <= valor_prioridad(primera) do
      [necesidad | lista]
    else
      [primera | insertar(necesidad, resto)]
    end
  end

  # cambia la prioridad por su numero (critica es 1). si la prioridad no se reconoce le da 5 para que quede de ultima
  defp valor_prioridad(necesidad), do: Map.get(@prioridades, necesidad.prioridad, 5)

  @doc "esta funcion arma una linea de texto con los datos de la necesidad, para mostrarla en pantalla."
  def describir(n) do
    recurso = if n.recurso == "", do: "", else: " | recurso: #{n.recurso}"

    "#{n.id} | #{n.tipo} x#{n.cantidad} | prioridad: #{n.prioridad} | zona: #{n.zona} | " <>
      "estado: #{n.estado} | reporta: #{n.responsable} | #{n.descripcion}#{recurso}"
  end
end
