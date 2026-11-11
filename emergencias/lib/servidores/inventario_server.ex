defmodule InventarioServer do
  @moduledoc """
  este modulo es un servidor (GenServer) que guarda el inventario de recursos y el historial de movimientos: registros, entradas, salidas, transferencias y asignaciones.

  el estado es un mapa con dos partes: `recursos`, donde la llave es el codigo, y `movimientos`, que es una lista. cada movimiento es la tupla `{fecha, codigo, tipo, ubicacion, cantidad, detalle}`.

  todo el inventario esta en un solo proceso y el GenServer atiende un mensaje a la vez. por eso, mientras se revisa cuanto hay y se descuenta, ninguna otra solicitud se mete en medio y nunca se asigna mas de lo que hay.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  use GenServer

  @doc "esta funcion inicia el servidor con el nombre `InventarioServer`. la usa el Supervisor."
  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @doc """
  esta funcion sirve para registrar un recurso nuevo con su cantidad inicial en una ubicacion.
  el `usuario` es quien hace el registro y queda guardado en el historial de movimientos.
  devuelve `{:ok, mensaje}` o `{:error, mensaje}`.
  """
  def registrar(codigo, nombre, categoria, cantidad, unidad, ubicacion, usuario),
    do: GenServer.call(__MODULE__, {:registrar, codigo, nombre, categoria, cantidad, unidad, ubicacion, usuario})

  @doc "esta funcion sirve para sumar unidades de un recurso en una ubicacion."
  def entrada(codigo, ubicacion, cantidad, usuario),
    do: GenServer.call(__MODULE__, {:entrada, codigo, ubicacion, cantidad, usuario})

  @doc "esta funcion sirve para descontar unidades de un recurso en una ubicacion. falla si no hay suficiente."
  def salida(codigo, ubicacion, cantidad, usuario),
    do: GenServer.call(__MODULE__, {:salida, codigo, ubicacion, cantidad, usuario})

  @doc "esta funcion sirve para mover unidades de un recurso de una ubicacion origen a otra ubicacion destino."
  def transferir(codigo, origen, destino, cantidad, usuario),
    do: GenServer.call(__MODULE__, {:transferir, codigo, origen, destino, cantidad, usuario})

  @doc """
  esta funcion sirve para descontar un recurso y usarlo en una necesidad.
  la categoria del recurso tiene que ser la misma que el tipo de la necesidad.
  devuelve `{:ok, recurso}` o `{:error, mensaje}`. la usa `NecesidadesServer`.
  """
  def asignar(codigo, ubicacion, cantidad, tipo_necesidad, id_necesidad),
    do: GenServer.call(__MODULE__, {:asignar, codigo, ubicacion, cantidad, tipo_necesidad, id_necesidad})

  @doc "esta funcion devuelve la lista de recursos ordenada por codigo."
  def listar, do: GenServer.call(__MODULE__, :listar)

  @doc "esta funcion devuelve el historial de movimientos de un recurso."
  def movimientos(codigo), do: GenServer.call(__MODULE__, {:movimientos, codigo})

  # al arrancar, carga los recursos y los movimientos que estaban guardados en los archivos
  @impl true
  def init(_) do
    {:ok, %{recursos: Persistencia.cargar_recursos(), movimientos: Persistencia.cargar_movimientos()}}
  end

  # recibe cada solicitud que llega al servidor y las atiende una por una
  @impl true
  def handle_call({:registrar, codigo, nombre, categoria, cantidad, unidad, ubicacion, usuario}, _from, estado) do
    if Map.has_key?(estado.recursos, codigo) do
      {:reply, {:error, "Ya existe el recurso #{codigo}. Para sumar unidades use entrada_recurso"}, estado}
    else
      case Recurso.crear(codigo, nombre, categoria, cantidad, unidad, ubicacion) do
        {:ok, recurso} ->
          movimiento = {Util.fecha_actual(), codigo, "registro", ubicacion, cantidad, usuario}
          respuesta = {:ok, "Se registro el recurso #{codigo} con #{cantidad} #{unidad} en #{ubicacion}"}
          {:reply, respuesta, guardar(estado, recurso, movimiento)}

        error ->
          {:reply, error, estado}
      end
    end
  end

  def handle_call({:entrada, codigo, ubicacion, cantidad, usuario}, _from, estado) do
    movimiento = {Util.fecha_actual(), codigo, "entrada", ubicacion, cantidad, usuario}
    {respuesta, nuevo} = operar(estado, codigo, movimiento, fn r -> Recurso.agregar(r, ubicacion, cantidad) end)
    {:reply, informar(respuesta, ubicacion), nuevo}
  end

  def handle_call({:salida, codigo, ubicacion, cantidad, usuario}, _from, estado) do
    movimiento = {Util.fecha_actual(), codigo, "salida", ubicacion, cantidad, usuario}
    {respuesta, nuevo} = operar(estado, codigo, movimiento, fn r -> Recurso.retirar(r, ubicacion, cantidad) end)
    {:reply, informar(respuesta, ubicacion), nuevo}
  end

  def handle_call({:transferir, codigo, origen, destino, cantidad, usuario}, _from, estado) do
    movimiento = {Util.fecha_actual(), codigo, "transferencia", origen <> " -> " <> destino, cantidad, usuario}

    {respuesta, nuevo} =
      operar(estado, codigo, movimiento, fn r -> Recurso.transferir(r, origen, destino, cantidad) end)

    {:reply, informar(respuesta, destino), nuevo}
  end

  def handle_call({:asignar, codigo, ubicacion, cantidad, tipo_necesidad, id_necesidad}, _from, estado) do
    movimiento = {Util.fecha_actual(), codigo, "asignacion", ubicacion, cantidad, id_necesidad}

    {respuesta, nuevo} =
      operar(estado, codigo, movimiento, fn r -> Recurso.asignar(r, ubicacion, cantidad, tipo_necesidad) end)

    {:reply, respuesta, nuevo}
  end

  def handle_call(:listar, _from, estado) do
    {:reply, Enum.sort_by(Map.values(estado.recursos), & &1.codigo), estado}
  end

  def handle_call({:movimientos, codigo}, _from, estado) do
    {:reply, Enum.filter(estado.movimientos, fn movimiento -> elem(movimiento, 1) == codigo end), estado}
  end

  # busca el recurso y aplica la operacion. solo si sale bien, guarda el cambio y el movimiento
  defp operar(estado, codigo, movimiento, operacion) do
    case Map.get(estado.recursos, codigo) do
      nil ->
        {{:error, "No existe ningun recurso con el codigo #{codigo}"}, estado}

      recurso ->
        case operacion.(recurso) do
          {:ok, actualizado} -> {{:ok, actualizado}, guardar(estado, actualizado, movimiento)}
          error -> {error, estado}
        end
    end
  end

  # pone el recurso actualizado en el mapa, guarda el inventario y agrega el movimiento al historial
  defp guardar(estado, recurso, movimiento) do
    recursos = Map.put(estado.recursos, recurso.codigo, recurso)
    Persistencia.guardar_recursos(recursos)
    Persistencia.agregar_movimiento(movimiento)
    %{estado | recursos: recursos, movimientos: estado.movimientos ++ [movimiento]}
  end

  # arma el mensaje de respuesta con lo que queda en la ubicacion. si hubo un error, lo deja pasar igual
  defp informar({:ok, recurso}, ubicacion),
    do: {:ok, "Ahora hay #{Recurso.disponible(recurso, ubicacion)} #{recurso.unidad} de #{recurso.codigo} en #{ubicacion}"}

  defp informar(error, _ubicacion), do: error
end
