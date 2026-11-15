defmodule AlberguesServer do
  @moduledoc """
  este modulo es un servidor (GenServer) que guarda todos los albergues. los demas modulos solo le piden o le pasan datos.

  el estado es un mapa donde la llave es el codigo del albergue y el valor es el albergue. cada cambio se guarda en el archivo albergues.txt.

  los ingresos se atienden uno a la vez, porque si queda un solo cupo y llegan dos personas al mismo tiempo, solo debe entrar una.

  este modulo llama a `FamiliasServer`, pero `FamiliasServer` nunca lo llama a el. si se llamaran entre los dos podria pasar un deadlock y los dos se quedarian esperando.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  use GenServer

  @doc "esta funcion inicia el servidor con el nombre `AlberguesServer`. la usa el Supervisor."
  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @doc """
  esta funcion sirve para registrar un albergue nuevo.
  recibe el codigo, el nombre, la zona y la capacidad.
  devuelve `{:ok, mensaje}` si sale bien o `{:error, mensaje}` si el codigo ya existe o los datos no son validos.
  """
  def registrar(codigo, nombre, zona, capacidad),
    do: GenServer.call(__MODULE__, {:registrar, codigo, nombre, zona, capacidad})

  @doc "esta funcion busca un albergue por su codigo. devuelve `{:ok, albergue}` si lo encuentra o `{:error, mensaje}` si no."
  def obtener(codigo), do: GenServer.call(__MODULE__, {:obtener, codigo})

  @doc "esta funcion revisa si hay un albergue con ese codigo. devuelve `true` si existe y `false` si no."
  def existe?(codigo), do: match?({:ok, _albergue}, obtener(codigo))

  @doc "esta funcion devuelve la lista de albergues ordenada por codigo."
  def listar, do: GenServer.call(__MODULE__, :listar)

  @doc """
  esta funcion sirve para que una persona entre a un albergue.
  recibe el codigo del albergue y el documento de la persona.
  primero revisa que haya cupo y despues cambia el estado de la persona a "en_albergue".
  devuelve `{:ok, mensaje}` o `{:error, mensaje}`.
  """
  def ingreso(codigo, documento), do: GenServer.call(__MODULE__, {:ingreso, codigo, documento})

  @doc """
  esta funcion sirve para que una persona salga de un albergue.
  el estado nuevo de la persona tiene que ser "trasladada" o "reunificada".
  devuelve `{:ok, mensaje}` o `{:error, mensaje}`.
  """
  def salida(codigo, documento, estado), do: GenServer.call(__MODULE__, {:salida, codigo, documento, estado})

  # al arrancar, carga los albergues que estaban guardados en el archivo
  @impl true
  def init(_), do: {:ok, Persistencia.cargar_albergues()}

  # recibe cada solicitud que llega al servidor y las atiende una por una
  @impl true
  def handle_call({:registrar, codigo, nombre, zona, capacidad}, _from, albergues) do
    if Map.has_key?(albergues, codigo) do
      {:reply, {:error, "Ya hay un albergue con el codigo #{codigo}"}, albergues}
    else
      case Albergue.crear(codigo, nombre, zona, capacidad) do
        {:ok, albergue} ->
          {:reply, {:ok, "Se registro el albergue #{codigo} con capacidad de #{capacidad}"}, guardar(albergues, albergue)}

        error ->
          {:reply, error, albergues}
      end
    end
  end

  def handle_call({:obtener, codigo}, _from, albergues) do
    case Map.get(albergues, codigo) do
      nil -> {:reply, no_existe(codigo), albergues}
      albergue -> {:reply, {:ok, albergue}, albergues}
    end
  end

  def handle_call(:listar, _from, albergues) do
    {:reply, Enum.sort_by(Map.values(albergues), & &1.codigo), albergues}
  end

  def handle_call({:ingreso, codigo, documento}, _from, albergues) do
    case Map.get(albergues, codigo) do
      nil -> {:reply, no_existe(codigo), albergues}
      albergue -> ingresar(albergues, albergue, documento)
    end
  end

  def handle_call({:salida, codigo, documento, estado}, _from, albergues) do
    case Map.get(albergues, codigo) do
      nil -> {:reply, no_existe(codigo), albergues}
      albergue -> sacar(albergues, albergue, documento, estado)
    end
  end

  # primero revisa el cupo del albergue y despues cambia el estado de la persona a en_albergue
  defp ingresar(albergues, albergue, documento) do
    case Albergue.ingresar(albergue, documento) do
      {:ok, actualizado} ->
        case FamiliasServer.cambiar_estado(documento, "en_albergue") do
          {:ok, _texto} ->
            texto = "#{documento} ingreso al albergue #{albergue.codigo}. Cupos disponibles: #{Albergue.cupos(actualizado)}"
            {:reply, {:ok, texto}, guardar(albergues, actualizado)}

          error ->
            {:reply, error, albergues}
        end

      error ->
        {:reply, error, albergues}
    end
  end

  # saca a la persona del albergue y despues cambia su estado a trasladada o reunificada.
  # si el estado no es ninguno de esos dos, devuelve un error
  defp sacar(albergues, albergue, documento, estado) do
    if estado in ["trasladada", "reunificada"] do
      case Albergue.retirar(albergue, documento) do
        {:ok, actualizado} ->
          case FamiliasServer.cambiar_estado(documento, estado) do
            {:ok, _texto} ->
              {:reply, {:ok, "#{documento} salio del albergue #{albergue.codigo} (#{estado})"}, guardar(albergues, actualizado)}

            error ->
              {:reply, error, albergues}
          end

        error ->
          {:reply, error, albergues}
      end
    else
      {:reply, {:error, "Para salir del albergue, el estado tiene que ser trasladada o reunificada"}, albergues}
    end
  end

  # pone el albergue actualizado en el mapa y despues guarda todos los albergues en el archivo
  defp guardar(albergues, albergue) do
    nuevos = Map.put(albergues, albergue.codigo, albergue)
    Persistencia.guardar_albergues(nuevos)
    nuevos
  end

  # arma el error que se devuelve cuando no hay un albergue con ese codigo
  defp no_existe(codigo), do: {:error, "No existe ningun albergue con el codigo #{codigo}"}
end
