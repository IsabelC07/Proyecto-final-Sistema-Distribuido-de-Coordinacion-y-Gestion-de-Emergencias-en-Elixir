defmodule MascotasServer do
  @moduledoc """
  este modulo es un servidor (GenServer) que guarda los reportes de mascotas perdidas y encontradas, y busca si alguno se parece a otro.

  el estado es un mapa donde la llave es el id del reporte y el valor es la mascota. cada cambio se guarda en el archivo mascotas.txt.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  use GenServer

  @doc "esta funcion inicia el servidor con el nombre `MascotasServer`. la usa el Supervisor."
  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @doc """
  esta funcion sirve para registrar el reporte de una mascota perdida o encontrada.
  le asigna un id con el formato MA001, MA002 y asi sucesivamente.
  devuelve `{:ok, mensaje}` o `{:error, mensaje}`.
  """
  def reportar(tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas),
    do: GenServer.call(__MODULE__, {:reportar, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas})

  @doc "esta funcion devuelve la lista de reportes ordenada por id."
  def listar, do: GenServer.call(__MODULE__, :listar)

  @doc """
  esta funcion sirve para buscar posibles coincidencias entre los reportes que no estan resueltos.
  los reportes que se parecen quedan marcados como "posible_coincidencia".
  devuelve una lista de tuplas `{id_perdida, id_encontrada, puntaje}`, ordenada del puntaje mas alto al mas bajo.
  """
  def buscar_coincidencias, do: GenServer.call(__MODULE__, :buscar_coincidencias)

  @doc """
  esta funcion sirve para confirmar que una mascota perdida y una encontrada son la misma.
  al confirmar, los dos reportes quedan cerrados.
  devuelve `{:ok, mensaje}` o `{:error, mensaje}`.
  """
  def confirmar(id_perdida, id_encontrada), do: GenServer.call(__MODULE__, {:confirmar, id_perdida, id_encontrada})

  # al arrancar, carga los reportes que estaban guardados en el archivo
  @impl true
  def init(_), do: {:ok, Persistencia.cargar_mascotas()}

  # recibe cada solicitud que llega al servidor y las atiende una por una
  @impl true
  def handle_call({:reportar, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas}, _from, mascotas) do
    id = Util.generar_id("MA", map_size(mascotas) + 1)

    case Mascota.crear(id, tipo, especie, nombre, color, tamano, zona, contacto, caracteristicas) do
      {:ok, mascota} -> {:reply, {:ok, "Se registro el reporte #{id} de una mascota #{tipo}"}, guardar(mascotas, [mascota])}
      error -> {:reply, error, mascotas}
    end
  end

  def handle_call(:listar, _from, mascotas) do
    {:reply, Enum.sort_by(Map.values(mascotas), & &1.id), mascotas}
  end

  # toma los reportes que no estan resueltos, compara las perdidas con las encontradas y marca las que tienen posible coincidencia
  def handle_call(:buscar_coincidencias, _from, mascotas) do
    abiertas =
      mascotas
      |> Map.values()
      |> Enum.filter(&(&1.estado != "resuelta"))
      |> Enum.sort_by(& &1.id)

    perdidas = Enum.filter(abiertas, &(&1.tipo == "perdida"))
    encontradas = Enum.filter(abiertas, &(&1.tipo == "encontrada"))

    pares =
      Mascota.coincidencias(perdidas, encontradas)
      |> Enum.sort_by(fn {_perdida, _encontrada, puntaje} -> puntaje end, :desc)

    marcadas =
      for {perdida, encontrada, _puntaje} <- pares, id <- [perdida, encontrada] do
        Mascota.marcar_posible(mascotas[id])
      end

    {:reply, pares, guardar(mascotas, marcadas)}
  end

  def handle_call({:confirmar, id_perdida, id_encontrada}, _from, mascotas) do
    case Mascota.confirmar(Map.get(mascotas, id_perdida), Map.get(mascotas, id_encontrada)) do
      {:ok, perdida, encontrada} ->
        texto = "Se confirmo la coincidencia: los reportes #{id_perdida} y #{id_encontrada} quedaron resueltos"
        {:reply, {:ok, texto}, guardar(mascotas, [perdida, encontrada])}

      error ->
        {:reply, error, mascotas}
    end
  end

  # actualiza los reportes que cambiaron y guarda todos en el archivo. si no cambio ninguno, no escribe nada
  defp guardar(mascotas, []), do: mascotas

  defp guardar(mascotas, cambiadas) do
    nuevas = Enum.reduce(cambiadas, mascotas, fn mascota, acumulado -> Map.put(acumulado, mascota.id, mascota) end)
    Persistencia.guardar_mascotas(nuevas)
    nuevas
  end
end
