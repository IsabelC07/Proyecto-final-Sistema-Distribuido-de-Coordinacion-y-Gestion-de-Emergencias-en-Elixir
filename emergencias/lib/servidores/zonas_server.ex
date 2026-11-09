defmodule ZonasServer do
  @moduledoc """
  este modulo es un servidor (GenServer) que guarda las zonas, los sectores y los puntos de atencion. los demas modulos solo le piden o le pasan datos.

  el estado es una lista con las zonas principales. cada zona guarda sus sectores en `hijos` y cada sector guarda sus puntos igual, porque asi todo queda en forma de arbol.

  cada cambio se guarda en el archivo zonas.txt.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  use GenServer

  @doc "esta funcion inicia el servidor con el nombre `ZonasServer`. la usa el Supervisor."
  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @doc """
  esta funcion sirve para registrar una zona principal, que es una zona que no tiene padre.
  recibe el codigo, el nombre, el nivel y los afectados.
  devuelve `{:ok, mensaje}` si sale bien o `{:error, mensaje}` si algo falla.
  """
  def registrar_zona(codigo, nombre, nivel, afectados),
    do: GenServer.call(__MODULE__, {:registrar, "", "zona", codigo, nombre, nivel, afectados})

  @doc """
  esta funcion sirve para agregar un sector a una zona o un punto a un sector.
  recibe el codigo del padre y los datos del elemento nuevo.
  el `tipo` solo puede ser "sector" o "punto".
  si todo sale bien devuelve `{:ok, mensaje}` y si algo falla devuelve `{:error, mensaje}`.
  """
  def registrar_hijo(codigo_padre, tipo, codigo, nombre, nivel, afectados),
    do: GenServer.call(__MODULE__, {:registrar, codigo_padre, tipo, codigo, nombre, nivel, afectados})

  @doc "esta funcion devuelve todo el arbol de zonas."
  def listar, do: GenServer.call(__MODULE__, :listar)

  @doc "esta funcion busca una zona, sector o punto por su codigo. devuelve `{:ok, zona}` si lo encuentra o `{:error, mensaje}` si no."
  def obtener(codigo), do: GenServer.call(__MODULE__, {:obtener, codigo})

  @doc "esta funcion revisa si ya hay una zona, sector o punto con ese codigo. devuelve `true` si lo encuentra y `false` si no."
  def existe?(codigo), do: match?({:ok, _zona}, obtener(codigo))

  # al arrancar, carga el arbol de zonas que estaba guardado en el archivo
  @impl true
  def init(_), do: {:ok, Persistencia.cargar_zonas()}

  # recibe cada solicitud que llega al servidor y las atiende una por una
  @impl true
  def handle_call({:registrar, codigo_padre, tipo, codigo, nombre, nivel, afectados}, _from, zonas) do
    case validar_ubicacion(zonas, codigo_padre, tipo, codigo) do
      :ok ->
        case Zona.crear(codigo, nombre, tipo, nivel, afectados) do
          {:ok, zona} ->
            nuevas = agregar(zonas, codigo_padre, zona)
            Persistencia.guardar_zonas(nuevas)
            {:reply, {:ok, "Se registro #{con_articulo(tipo)} #{codigo} correctamente"}, nuevas}

          error ->
            {:reply, error, zonas}
        end

      error ->
        {:reply, error, zonas}
    end
  end

  def handle_call(:listar, _from, zonas), do: {:reply, zonas, zonas}

  def handle_call({:obtener, codigo}, _from, zonas) do
    case Zona.buscar(zonas, codigo) do
      nil -> {:reply, {:error, "No existe ninguna zona, sector o punto con el codigo #{codigo}"}, zonas}
      zona -> {:reply, {:ok, zona}, zonas}
    end
  end

  # primero revisa que el codigo no este repetido. despues, si no es una zona, revisa que el padre exista y que sea del tipo correcto
  defp validar_ubicacion(zonas, codigo_padre, tipo, codigo) do
    padre = Zona.buscar(zonas, codigo_padre)

    cond do
      Zona.buscar(zonas, codigo) != nil ->
        {:error, "Ya hay una zona, sector o punto con el codigo #{codigo}"}

      tipo == "zona" ->
        :ok

      padre == nil ->
        {:error, "No existe el padre con el codigo #{codigo_padre}"}

      not Zona.padre_valido?(padre, tipo) ->
        {:error, "Un sector solo puede ir dentro de una zona y un punto solo puede ir dentro de un sector"}

      true ->
        :ok
    end
  end

  # agrega el articulo que va antes del tipo: "la zona", "el sector" o "el punto"
  defp con_articulo("zona"), do: "la zona"
  defp con_articulo(tipo), do: "el " <> tipo

  # si el codigo del padre esta vacio, la agrega como zona principal. si no, la agrega dentro del padre
  defp agregar(zonas, "", zona), do: zonas ++ [zona]
  defp agregar(zonas, codigo_padre, zona), do: Zona.agregar_hijo(zonas, codigo_padre, zona)
end
