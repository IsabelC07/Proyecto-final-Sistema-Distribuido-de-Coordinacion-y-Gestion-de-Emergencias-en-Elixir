defmodule UsuariosServer do
  @moduledoc """
  este modulo es un servidor (GenServer) que guarda los usuarios, sabe quienes estan conectados y revisa si un usuario tiene permiso para usar un comando.

  el estado es un mapa con dos partes: `usuarios`, donde la llave es el nombre de usuario, y `conectados`, un MapSet con los nombres de los que estan conectados. los usuarios se guardan en el archivo usuarios.txt.

  la primera vez que arranca el sistema se crea el usuario "admin" con clave "admin".

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  use GenServer

  @doc "esta funcion inicia el servidor con el nombre `UsuariosServer`. la usa el Supervisor."
  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @doc """
  esta funcion sirve para conectar a un usuario.

  primero busca si el usuario ya existe. si existe, revisa que la clave sea correcta.
  si no existe, lo registra y lo conecta, pero solo se puede registrar como ciudadano o voluntario.
  devuelve `{:ok, mensaje}` o `{:error, mensaje}`.
  """
  def conectar(usuario, clave, nombre, tipo, zona),
    do: GenServer.call(__MODULE__, {:conectar, usuario, clave, nombre, tipo, zona})

  @doc "esta funcion sirve para desconectar a un usuario. devuelve `{:ok, mensaje}`."
  def desconectar(usuario), do: GenServer.call(__MODULE__, {:desconectar, usuario})

  @doc """
  esta funcion sirve para crear un usuario de cualquier tipo. la usa el administrador con el comando crear_usuario.
  devuelve `{:ok, mensaje}` o `{:error, mensaje}` si el usuario ya existe o los datos no son validos.
  """
  def crear(usuario, clave, nombre, tipo, zona),
    do: GenServer.call(__MODULE__, {:crear, usuario, clave, nombre, tipo, zona})

  @doc """
  esta funcion sirve para saber si un usuario puede usar un comando.
  hace dos revisiones: primero que el usuario este conectado y despues que su tipo tenga permiso para ese comando.
  devuelve `:ok` si pasa las dos o `{:error, mensaje}` si alguna falla.
  """
  def autorizar(usuario, comando), do: GenServer.call(__MODULE__, {:autorizar, usuario, comando})

  # al arrancar, carga los usuarios del archivo. si no hay ninguno, crea el administrador inicial
  @impl true
  def init(_) do
    usuarios = Persistencia.cargar_usuarios()

    usuarios =
      if map_size(usuarios) == 0 do
        crear_admin_inicial()
      else
        usuarios
      end

    {:ok, %{usuarios: usuarios, conectados: MapSet.new()}}
  end

  # recibe cada solicitud que llega al servidor y las atiende una por una.
  # en conectar, si el usuario no existe se registra automaticamente y si ya existe se valida la clave
  @impl true
  def handle_call({:conectar, usuario, clave, nombre, tipo, zona}, _from, estado) do
    case Map.get(estado.usuarios, usuario) do
      nil -> registrar_y_conectar(usuario, clave, nombre, tipo, zona, estado)
      existente -> validar_y_conectar(existente, clave, estado)
    end
  end

  def handle_call({:desconectar, usuario}, _from, estado) do
    nuevo = %{estado | conectados: MapSet.delete(estado.conectados, usuario)}
    {:reply, {:ok, "El usuario #{usuario} se desconecto correctamente"}, nuevo}
  end

  def handle_call({:crear, usuario, clave, nombre, tipo, zona}, _from, estado) do
    if Map.has_key?(estado.usuarios, usuario) do
      {:reply, {:error, "Ya existe un usuario con el nombre #{usuario}"}, estado}
    else
      case Usuario.crear(usuario, clave, nombre, tipo, zona) do
        {:ok, nuevo_usuario} ->
          {:reply, {:ok, "Se creo el usuario #{usuario} como #{tipo}"}, guardar(estado, nuevo_usuario)}

        error ->
          {:reply, error, estado}
      end
    end
  end

  def handle_call({:autorizar, usuario, comando}, _from, estado) do
    respuesta =
      cond do
        not MapSet.member?(estado.conectados, usuario) ->
          {:error, "El usuario #{usuario} no esta conectado"}

        Usuario.puede?(estado.usuarios[usuario].tipo, comando) ->
          :ok

        true ->
          {:error, "Un usuario de tipo #{estado.usuarios[usuario].tipo} no tiene permiso para usar #{comando}"}
      end

    {:reply, respuesta, estado}
  end

  # registra un usuario nuevo, solo como ciudadano o voluntario, y lo deja conectado
  defp registrar_y_conectar(usuario, clave, nombre, tipo, zona, estado) do
    case Usuario.validar_autoregistro(tipo) do
      :ok ->
        case Usuario.crear(usuario, clave, nombre, tipo, zona) do
          {:ok, nuevo_usuario} ->
            nuevo = guardar(estado, nuevo_usuario)
            nuevo = %{nuevo | conectados: MapSet.put(nuevo.conectados, usuario)}
            {:reply, {:ok, "Se registro el usuario #{usuario} como #{tipo} y quedo conectado"}, nuevo}

          error ->
            {:reply, error, estado}
        end

      error ->
        {:reply, error, estado}
    end
  end

  # revisa la clave del usuario que ya existe. si es correcta, lo conecta
  defp validar_y_conectar(existente, clave, estado) do
    if Usuario.clave_correcta?(existente, clave) do
      nuevo = %{estado | conectados: MapSet.put(estado.conectados, existente.usuario)}
      {:reply, {:ok, "Bienvenido #{existente.nombre}. Se conecto como #{existente.tipo}"}, nuevo}
    else
      {:reply, {:error, "La clave es incorrecta. Intente de nuevo."}, estado}
    end
  end

  # agrega o actualiza el usuario en el mapa y guarda todos los usuarios en el archivo
  defp guardar(estado, usuario) do
    usuarios = Map.put(estado.usuarios, usuario.usuario, usuario)
    Persistencia.guardar_usuarios(usuarios)
    %{estado | usuarios: usuarios}
  end

  # la primera vez que arranca el sistema no hay usuarios, entonces se crea un administrador
  defp crear_admin_inicial do
    {:ok, admin} = Usuario.crear("admin", "admin", "Administrador", "administrador", "general")
    usuarios = %{"admin" => admin}
    Persistencia.guardar_usuarios(usuarios)
    usuarios
  end
end
