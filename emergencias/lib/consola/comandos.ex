defmodule Comandos do
  @moduledoc """
  en este modulo recibe la linea que escribe el usuario en la consola, entonces revisa
  si tiene los permisos para usar el comando y llama al servidor que da respuesta
  tambien se encarga de contruir los reportes, por ejemplo el estado de una zona, el resumen general
  y los recursos criticos.
  Cada comando que se ejecuta queda guardado en la bitacora
  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  # lista de los comandos. Cada elemento es un par: primero va el nombre del comando y
  # después la forma correcta de escribirlo, que es lo que se muestra en "ayuda"
  @usos [
    {"ayuda", "ayuda"},
    {"salir", "salir"},
    {"conectar", "conectar usuario clave [tipo zona \"Nombre completo\"]"},
    {"desconectar", "desconectar"},
    {"crear_usuario", "crear_usuario usuario clave tipo zona \"Nombre completo\""},
    {"registrar_zona", "registrar_zona codigo \"nombre\" critico|alto|medio|bajo afectados"},
    {"registrar_sector", "registrar_sector zona codigo \"nombre\" critico|alto|medio|bajo afectados"},
    {"registrar_punto", "registrar_punto sector codigo \"nombre\" critico|alto|medio|bajo afectados"},
    {"listar_zonas", "listar_zonas"}
  ]

  @doc """
  funciona para que se ejecute una linea que se escribio en la consola
  separa la linea en el comando y sus argumentos, ejecuta el comando y guarda lo que pasó en la bitácora.

  si el comando funciona devuelve {usuario_activo, {:ok, texto}} y si falla da
  {usuario_activo, {:error, texto}}. Cuando el usuario escribe salir devuelve :salir.
  """
  def ejecutar(linea, usuario) do
    case Parser.tokenizar(linea) do
      [] ->
        {usuario, {:ok, ""}}

      [comando | argumentos] ->
        comando = String.downcase(comando)
        respuesta = ejecutar_comando(comando, argumentos, usuario)
        registrar_actividad(comando, argumentos, usuario, respuesta)
        respuesta
    end
  end

  # los comandos salir, ayuda y conectar son los unicos que se pueden usar sin una sesion.
  # con los demás comandos primero se revisa el permiso del usuario en autorizar.
  defp ejecutar_comando("salir", _argumentos, _usuario), do: :salir
  defp ejecutar_comando("ayuda", _argumentos, usuario), do: {usuario, {:ok, ayuda()}}
  defp ejecutar_comando("conectar", argumentos, usuario), do: conectar(argumentos, usuario)

  defp ejecutar_comando(comando, argumentos, usuario) do
    case autorizar(comando, usuario) do
      :ok when comando == "desconectar" -> {nil, UsuariosServer.desconectar(usuario)}
      :ok -> {usuario, despachar(comando, argumentos, usuario)}
      error -> {usuario, error}
    end
  end

  #comandos
  # despachar/3 recibe el nombre del comando y sus argumentos, y llama al servidor que corresponde.
  # hay una version de despachar por cada comando y se elige la que coincide con el nombre y los argumentos.

  #usuarios
  defp despachar("crear_usuario", [nuevo, clave, tipo, zona, nombre], _usuario),
    do: UsuariosServer.crear(nuevo, clave, nombre, tipo, zona)

  #zonas
  defp despachar("registrar_zona", [codigo, nombre, nivel, afectados], _usuario) do
    if codigo_libre?(codigo) do
      ZonasServer.registrar_zona(codigo, nombre, nivel, Parser.entero(afectados))
    else
      codigo_ocupado(codigo)
    end
  end

  defp despachar("registrar_sector", [zona, codigo, nombre, nivel, afectados], _usuario),
    do: registrar_hijo(zona, "sector", codigo, nombre, nivel, afectados)

  defp despachar("registrar_punto", [sector, codigo, nombre, nivel, afectados], _usuario),
    do: registrar_hijo(sector, "punto", codigo, nombre, nivel, afectados)

  defp despachar("listar_zonas", [], _usuario) do
    case ZonasServer.listar() do
      [] -> {:ok, "todavia no se tiene ni una sola zona registrada. por tanto, tiene que usar registrar_zona para crear una"}
      zonas -> {:ok, String.trim_trailing(Zona.describir_arbol(zonas, ""))}
    end
  end

  # este caso se esta usando cuando los argumentos no coinciden con ninguna version de despachar
  # de arriba. muestra como se deberia de escribir el cmando
  defp despachar(comando, _argumentos, _usuario), do: {:error, "Uso correcto: " <> uso(comando)}

  #funciones de apoyo

  # estas funciones conectan al usuario. si el usuario no existe este se crea
  # si solo se escribe usuario y clave, queda ciudadano y sin zona
  defp conectar([nombre_usuario, clave], usuario_actual),
    do: conectar([nombre_usuario, clave, "ciudadano", "sin_zona", nombre_usuario], usuario_actual)

  defp conectar([nombre_usuario, clave, tipo, zona], usuario_actual),
    do: conectar([nombre_usuario, clave, tipo, zona, nombre_usuario], usuario_actual)

  defp conectar([nombre_usuario, clave, tipo, zona, nombre], usuario_actual) do
    case UsuariosServer.conectar(nombre_usuario, clave, nombre, tipo, zona) do
      {:ok, texto} -> {nombre_usuario, {:ok, texto}}
      error -> {usuario_actual, error}
    end
  end

  defp conectar(_argumentos, usuario_actual), do: {usuario_actual, {:error, "Uso correcto: " <> uso("conectar")}}

  # revisa tres cosas: que el comando exista, que haya un usuario conectado
  # y que ese usuario tenga permiso para usarlo
  defp autorizar(comando, usuario) do
    cond do
      List.keyfind(@usos, comando, 0) == nil -> {:error, "el comando #{comando} no existe. escriba ayuda para ver la lista de comando completa que tienee el sistema"}
      usuario == nil -> {:error, "Primero debe conectarse así: " <> uso("conectar")}
      true -> UsuariosServer.autorizar(usuario, comando)
    end
  end

  # hace guardado en la bitacora lo que hizo el usuario. con conectar y crear_usuario solo se
  # guarda el nombre de usuario, para que las claves no queden escritas.
  defp registrar_actividad(comando, argumentos, usuario, respuesta) do
    {quien, resultado} =
      case respuesta do
        :salir -> {usuario, :ok}
        {usuario_activo, {resultado, _texto}} -> {usuario_activo || usuario, resultado}
      end

    detalle =
      if comando in ["conectar", "crear_usuario"] do
        "#{comando} #{List.first(argumentos)}"
      else
        Enum.join([comando | argumentos], " ")
      end

    Bitacora.registrar(quien || "sin_sesion", detalle, resultado)
  end

  # arma el texto de ayuda con todos los comandos y la forma en la que tiene que escribirlo
  defp ayuda do
    "lista de comandos (si un texto tiene espacios, escribalo entre comillas):\n" <>
      Enum.map_join(@usos, "\n", fn {_comando, texto} -> "  " <> texto end)
  end

  # busco en @usos cómo se escribe un comando. Si no lo encuentra devuelve "escriba ayuda"
  defp uso(comando) do
    case List.keyfind(@usos, comando, 0) do
      {_comando, texto} -> texto
      nil -> "escriba ayuda"
    end
  end

  # esta funcion sirve para registrar un sector o un punto. Primero revisa que el código
  # no esté actualmente en uso y, si esta libre, lo registra dentro del padre indicado.
  defp registrar_hijo(padre, tipo, codigo, nombre, nivel, afectados) do
    if codigo_libre?(codigo) do
      ZonasServer.registrar_hijo(padre, tipo, codigo, nombre, nivel, Parser.entero(afectados))
    else
      codigo_ocupado(codigo)
    end
  end

  # Revisa si el código es de una ubicación que existe. Una ubicación puede ser una zona,
  # un sector o un punto de atención.
  defp ubicacion_valida?(codigo), do: ZonasServer.existe?(codigo)

  # Revisa si un código está libre, es decir, que ninguna zona, sector ni punto lo use
  defp codigo_libre?(codigo), do: not ubicacion_valida?(codigo)

  defp codigo_ocupado(codigo), do: {:error, "el codigo #{codigo} se encuentra ocupado, debe escojerse otro"}
end
