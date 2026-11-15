defmodule FamiliasServer do
  @moduledoc """
  este modulo es un servidor (GenServer) que guarda las personas reportadas y los mensajes que se les dejan. sirve para ayudar a reunir a las familias.

  el estado es un mapa con dos partes: `personas`, donde la llave es el documento, y `mensajes`, donde la llave es el id.

  los cambios se guardan en los archivos personas.txt, historial_personas.txt y mensajes.txt.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  use GenServer

  @doc "esta funcion inicia el servidor con el nombre `FamiliasServer`. la usa el Supervisor."
  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @doc """
  esta funcion sirve para reportar una persona nueva.
  le asigna un id con el formato P001, P002 y asi sucesivamente.
  devuelve `{:ok, mensaje}` si queda registrada o `{:error, mensaje}` si el documento ya existe o los datos no son validos.
  """
  def reportar(documento, nombre, edad, zona, estado),
    do: GenServer.call(__MODULE__, {:reportar, documento, nombre, edad, zona, estado})

  @doc "esta funcion busca una persona por su documento. devuelve `{:ok, persona}` si la encuentra o `{:error, mensaje}` si no."
  def obtener(documento), do: GenServer.call(__MODULE__, {:obtener, documento})

  @doc "esta funcion devuelve la lista de personas ordenada por id."
  def listar_personas, do: GenServer.call(__MODULE__, :listar_personas)

  @doc """
  esta funcion sirve para cambiar el estado de una persona sin las restricciones de albergue.
  la usa `AlberguesServer` cuando registra ingresos y salidas.
  """
  def cambiar_estado(documento, estado),
    do: GenServer.call(__MODULE__, {:cambiar_estado, documento, estado, false})

  @doc """
  esta funcion sirve para cambiar el estado de una persona cuando lo pide un usuario con el comando actualizar_persona.
  por esta via no se puede entrar ni salir de un albergue.
  """
  def actualizar_manual(documento, estado),
    do: GenServer.call(__MODULE__, {:cambiar_estado, documento, estado, true})

  @doc """
  esta funcion sirve para guardar un mensaje dirigido a la persona con ese documento.
  devuelve `{:ok, mensaje}` si se guarda o `{:error, mensaje}` si la persona no existe o el mensaje esta vacio.
  """
  def enviar_mensaje(remitente, documento, contenido),
    do: GenServer.call(__MODULE__, {:enviar_mensaje, remitente, documento, contenido})

  @doc "esta funcion devuelve los mensajes dirigidos a la persona con ese documento, ordenados por id."
  def mensajes_de(documento), do: GenServer.call(__MODULE__, {:mensajes_de, documento})

  @doc "esta funcion devuelve todos los mensajes guardados."
  def listar_mensajes, do: GenServer.call(__MODULE__, :listar_mensajes)

  @doc "esta funcion marca un mensaje como \"pendiente\" o \"entregado\". devuelve `{:ok, mensaje}` o `{:error, mensaje}`."
  def marcar_mensaje(id, estado), do: GenServer.call(__MODULE__, {:marcar_mensaje, id, estado})

  # al arrancar, carga las personas y los mensajes que estaban guardados en los archivos
  @impl true
  def init(_) do
    {:ok, %{personas: Persistencia.cargar_personas(), mensajes: Persistencia.cargar_mensajes()}}
  end

  # recibe cada solicitud que llega al servidor y las atiende una por una
  @impl true
  def handle_call({:reportar, documento, nombre, edad, zona, estado}, _from, datos) do
    if Map.has_key?(datos.personas, documento) do
      {:reply, {:error, "Ya hay una persona registrada con el documento #{documento}"}, datos}
    else
      id = Util.generar_id("P", map_size(datos.personas) + 1)

      case Persona.crear(id, documento, nombre, edad, zona, estado) do
        {:ok, persona} ->
          {:reply, {:ok, "Se registro a #{nombre} con el id #{id} y el estado #{estado}"}, guardar_persona(datos, persona)}

        error ->
          {:reply, error, datos}
      end
    end
  end

  def handle_call({:obtener, documento}, _from, datos) do
    case Map.get(datos.personas, documento) do
      nil -> {:reply, persona_no_existe(documento), datos}
      persona -> {:reply, {:ok, persona}, datos}
    end
  end

  def handle_call(:listar_personas, _from, datos) do
    {:reply, Enum.sort_by(Map.values(datos.personas), & &1.id), datos}
  end

  def handle_call({:cambiar_estado, documento, estado, manual}, _from, datos) do
    case Map.get(datos.personas, documento) do
      nil ->
        {:reply, persona_no_existe(documento), datos}

      persona ->
        case Persona.cambiar_estado(persona, estado, manual) do
          {:ok, actualizada} ->
            {:reply, {:ok, "#{actualizada.nombre} ahora tiene el estado #{estado}"}, guardar_persona(datos, actualizada)}

          error ->
            {:reply, error, datos}
        end
    end
  end

  def handle_call({:enviar_mensaje, remitente, documento, contenido}, _from, datos) do
    if Map.has_key?(datos.personas, documento) do
      id = Util.generar_id("MS", map_size(datos.mensajes) + 1)

      case Mensaje.crear(id, remitente, documento, contenido) do
        {:ok, mensaje} -> {:reply, {:ok, "Se guardo el mensaje #{id} para #{documento}"}, guardar_mensaje(datos, mensaje)}
        error -> {:reply, error, datos}
      end
    else
      {:reply, persona_no_existe(documento), datos}
    end
  end

  def handle_call({:mensajes_de, documento}, _from, datos) do
    mensajes =
      datos.mensajes
      |> Map.values()
      |> Enum.filter(&(&1.destinatario == documento))
      |> Enum.sort_by(& &1.id)

    {:reply, mensajes, datos}
  end

  def handle_call(:listar_mensajes, _from, datos), do: {:reply, Map.values(datos.mensajes), datos}

  def handle_call({:marcar_mensaje, id, estado}, _from, datos) do
    case Map.get(datos.mensajes, id) do
      nil ->
        {:reply, {:error, "No existe ningun mensaje con el id #{id}"}, datos}

      mensaje ->
        case Mensaje.marcar(mensaje, estado) do
          {:ok, actualizado} -> {:reply, {:ok, "Mensaje #{id} marcado como #{estado}"}, guardar_mensaje(datos, actualizado)}
          error -> {:reply, error, datos}
        end
    end
  end

  # pone la persona actualizada en el mapa, la guarda en el archivo y agrega su ultimo cambio de estado al historial
  defp guardar_persona(datos, persona) do
    personas = Map.put(datos.personas, persona.documento, persona)
    Persistencia.guardar_personas(personas)
    Persistencia.agregar_cambio_persona(persona.documento, List.last(persona.historial))
    %{datos | personas: personas}
  end

  # pone el mensaje actualizado en el estado y guarda todos los mensajes en el archivo
  defp guardar_mensaje(datos, mensaje) do
    mensajes = Map.put(datos.mensajes, mensaje.id, mensaje)
    Persistencia.guardar_mensajes(mensajes)
    %{datos | mensajes: mensajes}
  end

  # arma el error que se devuelve cuando no hay una persona con ese documento
  defp persona_no_existe(documento), do: {:error, "No hay ninguna persona con el documento #{documento}"}
end
