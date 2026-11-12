defmodule NecesidadesServer do
  @moduledoc """
  este modulo es un servidor (GenServer) que guarda las necesidades reportadas y controla su atencion: asignar recursos, ponerlas en atencion, atenderlas o cancelarlas.

  el estado es un mapa donde la llave es el id y el valor es la necesidad. cada cambio se guarda en el archivo necesidades.txt.

  este modulo llama a `InventarioServer`, pero `InventarioServer` nunca lo llama a el. asi no pasa un deadlock y ninguno se queda esperando al otro.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  use GenServer

  @doc "esta funcion inicia el servidor con el nombre `NecesidadesServer`. la usa el Supervisor."
  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @doc """
  esta funcion sirve para registrar una necesidad nueva.
  le asigna un id con el formato N001, N002 y asi sucesivamente.
  el `responsable` es el usuario que la reporta.
  devuelve `{:ok, mensaje}` o `{:error, mensaje}`.
  """
  def registrar(tipo, cantidad, prioridad, zona, descripcion, responsable),
    do: GenServer.call(__MODULE__, {:registrar, tipo, cantidad, prioridad, zona, descripcion, responsable})

  @doc "esta funcion devuelve la lista de necesidades ordenada por id."
  def listar, do: GenServer.call(__MODULE__, :listar)

  @doc """
  esta funcion sirve para asignar recursos a una necesidad pendiente.
  toma del recurso y la ubicacion indicados la cantidad completa que pide la necesidad.
  si el inventario no alcanza, se rechaza la asignacion.
  devuelve `{:ok, mensaje}` o `{:error, mensaje}`.
  """
  def asignar(id, codigo_recurso, ubicacion),
    do: GenServer.call(__MODULE__, {:asignar, id, codigo_recurso, ubicacion})

  @doc """
  esta funcion sirve para cambiar el estado de una necesidad a "en_atencion", "atendida" o "cancelada".
  para pasar a "asignada" hay que usar `asignar/3`.
  """
  def actualizar(id, estado), do: GenServer.call(__MODULE__, {:actualizar, id, estado})

  # al arrancar, carga las necesidades que estaban guardadas en el archivo
  @impl true
  def init(_), do: {:ok, Persistencia.cargar_necesidades()}

  # recibe cada solicitud que llega al servidor y las atiende una por una
  @impl true
  def handle_call({:registrar, tipo, cantidad, prioridad, zona, descripcion, responsable}, _from, necesidades) do
    id = Util.generar_id("N", map_size(necesidades) + 1)

    case Necesidad.crear(id, tipo, cantidad, prioridad, zona, descripcion, responsable) do
      {:ok, necesidad} ->
        respuesta = {:ok, "Se registro la necesidad #{id}: #{cantidad} de #{tipo} con prioridad #{prioridad}"}
        {:reply, respuesta, guardar(necesidades, necesidad)}

      error ->
        {:reply, error, necesidades}
    end
  end

  def handle_call(:listar, _from, necesidades) do
    {:reply, Enum.sort_by(Map.values(necesidades), & &1.id), necesidades}
  end

  def handle_call({:asignar, id, codigo_recurso, ubicacion}, _from, necesidades) do
    case Map.get(necesidades, id) do
      nil -> {:reply, no_existe(id), necesidades}
      necesidad -> asignar_recurso(necesidad, codigo_recurso, ubicacion, necesidades)
    end
  end

  def handle_call({:actualizar, id, estado}, _from, necesidades) do
    case Map.get(necesidades, id) do
      nil ->
        {:reply, no_existe(id), necesidades}

      _necesidad when estado == "asignada" ->
        {:reply, {:error, "Para asignar recursos hay que usar el comando asignar_recurso"}, necesidades}

      necesidad ->
        case Necesidad.cambiar_estado(necesidad, estado) do
          {:ok, actualizada} -> {:reply, {:ok, "La necesidad #{id} cambio a #{estado}"}, guardar(necesidades, actualizada)}
          error -> {:reply, error, necesidades}
        end
    end
  end

  # solo una necesidad pendiente puede recibir recursos. una necesidad atendida no vuelve a consumir inventario.
  # se pide la cantidad completa y, si el inventario no alcanza, se rechaza la asignacion.
  defp asignar_recurso(necesidad, codigo_recurso, ubicacion, necesidades) do
    case Necesidad.cambiar_estado(necesidad, "asignada") do
      {:ok, asignada} ->
        case InventarioServer.asignar(codigo_recurso, ubicacion, necesidad.cantidad, necesidad.tipo, necesidad.id) do
          {:ok, _recurso} ->
            asignada = %{asignada | recurso: "#{codigo_recurso} desde #{ubicacion}"}
            texto = "Necesidad #{necesidad.id}: se asignaron #{necesidad.cantidad} de #{codigo_recurso} desde #{ubicacion}"
            {:reply, {:ok, texto}, guardar(necesidades, asignada)}

          error ->
            {:reply, error, necesidades}
        end

      error ->
        {:reply, error, necesidades}
    end
  end

  # pone la necesidad actualizada en el mapa y guarda todas en el archivo
  defp guardar(necesidades, necesidad) do
    nuevas = Map.put(necesidades, necesidad.id, necesidad)
    Persistencia.guardar_necesidades(nuevas)
    nuevas
  end

  # arma el error que se devuelve cuando no hay una necesidad con ese id
  defp no_existe(id), do: {:error, "No existe ninguna necesidad con el id #{id}"}
end
