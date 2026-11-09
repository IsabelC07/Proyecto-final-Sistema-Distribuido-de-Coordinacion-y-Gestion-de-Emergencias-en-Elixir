defmodule Usuario do
  @moduledoc """
  en este modulo manejamos a los usuarios que entran al sistema y tambien dice que comandos puede usar cada uno segun su tipo.

  cada usuario tiene su nombre de usuario, que no se puede repetir, la clave, el nombre completo, el tipo y la zona. la clave se guarda tal cual, sin cifrar, porque es un proyecto de prueba.

  los tipos son "ciudadano", "voluntario", "coordinador" y "administrador". los permisos se van sumando, o sea que cada tipo puede usar sus comandos y tambien todos los del tipo que esta antes que el.

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """

  defstruct usuario: "", clave: "", nombre: "", tipo: "ciudadano", zona: ""

  @tipos ["ciudadano", "voluntario", "coordinador", "administrador"]

  # al conectarse, una persona solo se puede registrar sola como ciudadano o voluntario. los coordinadores y los administradores los tiene que crear un administrador, por seguridad
  @tipos_autoregistro ["ciudadano", "voluntario"]

  @comandos_ciudadano [
    "desconectar",
    "listar_zonas",
    "estado_zona",
    "registrar_necesidad",
    "listar_necesidades",
    "necesidades_pendientes",
    "listar_recursos",
    "reportar_persona",
    "buscar_persona",
    "historial_persona",
    "enviar_mensaje",
    "listar_mensajes",
    "reportar_mascota",
    "listar_mascotas",
    "consultar_albergue",
    "reporte_albergues"
  ]

  @comandos_voluntario [
    "actualizar_necesidad",
    "actualizar_persona",
    "marcar_mensaje",
    "registrar_ingreso",
    "registrar_salida",
    "entrada_recurso",
    "movimientos",
    "buscar_coincidencias"
  ]

  @comandos_coordinador [
    "registrar_zona",
    "registrar_sector",
    "registrar_punto",
    "registrar_recurso",
    "salida_recurso",
    "asignar_recurso",
    "transferir_recurso",
    "registrar_albergue",
    "confirmar_coincidencia",
    "resumen",
    "recursos_criticos",
    "simular_asignacion"
  ]

  @comandos_administrador ["crear_usuario"]

  @doc """
  esta funcion sirve para crear un usuario nuevo.
  recibe el usuario, la clave, el nombre, el tipo y la zona.
  devuelve `{:ok, usuario}` o `{:error, mensaje}` si falta el usuario o la clave, o si el tipo no existe.
  """
  def crear(usuario, clave, nombre, tipo, zona) do
    cond do
      usuario == "" or clave == "" ->
        {:error, "Falta el nombre de usuario o la clave"}

      tipo not in @tipos ->
        {:error, "Ese tipo de usuario no existe. Los que hay son: " <> Enum.join(@tipos, ", ")}

      true ->
        {:ok, %Usuario{usuario: usuario, clave: clave, nombre: nombre, tipo: tipo, zona: zona}}
    end
  end

  @doc """
  esta funcion revisa si una persona se puede registrar por su cuenta con el tipo que escogio.
  solo se deja si el tipo es "ciudadano" o "voluntario", los otros tipos los tiene que crear un administrador.
  devuelve `:ok` o `{:error, mensaje}`.
  """
  def validar_autoregistro(tipo) do
    if tipo in @tipos_autoregistro do
      :ok
    else
      {:error, "Solo te puedes registrar como ciudadano o voluntario, los otros tipos los crea un administrador"}
    end
  end

  @doc "esta funcion compara la clave que escribio la persona con la que tiene guardada el usuario. devuelve `true` si son iguales y `false` si no."
  def clave_correcta?(usuario, clave), do: usuario.clave == clave

  @doc """
  esta funcion devuelve un MapSet con todos los comandos que puede usar un tipo de usuario.
  a cada tipo se le suman los comandos del tipo anterior. si el tipo no existe devuelve un MapSet vacio, o sea sin ningun permiso.
  """
  def permisos("ciudadano"), do: MapSet.new(@comandos_ciudadano)
  def permisos("voluntario"), do: MapSet.union(permisos("ciudadano"), MapSet.new(@comandos_voluntario))
  def permisos("coordinador"), do: MapSet.union(permisos("voluntario"), MapSet.new(@comandos_coordinador))
  def permisos("administrador"), do: MapSet.union(permisos("coordinador"), MapSet.new(@comandos_administrador))
  def permisos(_tipo), do: MapSet.new()

  @doc "esta funcion revisa si un tipo de usuario tiene permiso para usar un comando. devuelve `true` o `false`."
  def puede?(tipo, comando), do: MapSet.member?(permisos(tipo), comando)
end
