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
    {"listar_zonas", "listar_zonas"},
    {"registrar_necesidad", "registrar_necesidad tipo cantidad critica|alta|media|baja zona \"descripcion\""},
    {"listar_necesidades", "listar_necesidades [zona=.. tipo=.. prioridad=.. estado=..]"},
    {"necesidades_pendientes", "necesidades_pendientes"},
    {"asignar_recurso", "asignar_recurso id_necesidad codigo_recurso ubicacion"},
    {"actualizar_necesidad", "actualizar_necesidad id_necesidad en_atencion|atendida|cancelada"},
    {"registrar_recurso", "registrar_recurso codigo \"nombre\" categoria cantidad unidad ubicacion"},
    {"entrada_recurso", "entrada_recurso codigo ubicacion cantidad"},
    {"salida_recurso", "salida_recurso codigo ubicacion cantidad"},
    {"transferir_recurso", "transferir_recurso codigo origen destino cantidad"},
    {"listar_recursos", "listar_recursos [categoria=.. zona=..]"},
    {"movimientos", "movimientos codigo_recurso"},
    {"reportar_persona", "reportar_persona documento \"nombre\" edad zona sin_informacion|reportada|localizada"},
    {"buscar_persona", "buscar_persona [documento=.. nombre=.. zona=.. estado=..]"},
    {"historial_persona", "historial_persona documento"},
    {"actualizar_persona", "actualizar_persona documento estado"},
    {"enviar_mensaje", "enviar_mensaje documento \"mensaje\""},
    {"listar_mensajes", "listar_mensajes documento"},
    {"marcar_mensaje", "marcar_mensaje id_mensaje entregado|pendiente"},
    {"registrar_albergue", "registrar_albergue codigo \"nombre\" zona capacidad"},
    {"consultar_albergue", "consultar_albergue codigo"},
    {"registrar_ingreso", "registrar_ingreso codigo_albergue documento"},
    {"registrar_salida", "registrar_salida codigo_albergue documento trasladada|reunificada"},
    {"reporte_albergues", "reporte_albergues"},
    {"recursos_criticos", "recursos_criticos"},
    {"simular_asignacion", "simular_asignacion codigo_recurso ubicacion id_necesidad1 id_necesidad2 ..."}
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

  #necesidades
  defp despachar("registrar_necesidad", [tipo, cantidad, prioridad, zona, descripcion], usuario) do
    if ubicacion_valida?(zona) do
      NecesidadesServer.registrar(tipo, Parser.entero(cantidad), prioridad, zona, descripcion, usuario)
    else
      ubicacion_invalida(zona)
    end
  end

  # lista todas las necesidades que cumplan los filtros escritos (zona, tipo, prioridad o estado).
  # la prioridad se usa para ordenar: primero salen las criticas.
  defp despachar("listar_necesidades", palabras, _usuario) do
    permitidos = %{"zona" => :zona, "tipo" => :tipo, "prioridad" => :prioridad, "estado" => :estado}

    case preparar_filtros(palabras, permitidos) do
      {:ok, filtros} ->
        NecesidadesServer.listar()
        |> Enum.filter(&cumple?(&1, filtros))
        |> Necesidad.ordenar_por_prioridad()
        |> listar_texto(&Necesidad.describir/1, "no necesita cumplir esos requisitos")

      error ->
        error
    end
  end

  defp despachar("necesidades_pendientes", [], _usuario) do
    NecesidadesServer.listar()
    |> Enum.filter(&(&1.estado == "pendiente"))
    |> Necesidad.ordenar_por_prioridad()
    |> listar_texto(&Necesidad.describir/1, "no se tienen necesidades pendientes")
  end

  defp despachar("asignar_recurso", [id, codigo, ubicacion], _usuario),
    do: NecesidadesServer.asignar(id, codigo, ubicacion)

  defp despachar("actualizar_necesidad", [id, estado], _usuario),
    do: NecesidadesServer.actualizar(id, estado)

  #recursos
  defp despachar("registrar_recurso", [codigo, nombre, categoria, cantidad, unidad, ubicacion], usuario) do
    if ubicacion_valida?(ubicacion) do
      InventarioServer.registrar(codigo, nombre, categoria, Parser.entero(cantidad), unidad, ubicacion, usuario)
    else
      ubicacion_invalida(ubicacion)
    end
  end

  defp despachar("entrada_recurso", [codigo, ubicacion, cantidad], usuario) do
    if ubicacion_valida?(ubicacion) do
      InventarioServer.entrada(codigo, ubicacion, Parser.entero(cantidad), usuario)
    else
      ubicacion_invalida(ubicacion)
    end
  end

  defp despachar("salida_recurso", [codigo, ubicacion, cantidad], usuario),
    do: InventarioServer.salida(codigo, ubicacion, Parser.entero(cantidad), usuario)

  defp despachar("transferir_recurso", [codigo, origen, destino, cantidad], usuario) do
    if ubicacion_valida?(destino) do
      InventarioServer.transferir(codigo, origen, destino, Parser.entero(cantidad), usuario)
    else
      ubicacion_invalida(destino)
    end
  end

  defp despachar("listar_recursos", palabras, _usuario) do
    case preparar_filtros(palabras, %{"categoria" => :categoria, "zona" => :zona}) do
      {:ok, filtros} ->
        InventarioServer.listar()
        |> Enum.filter(&cumple_categoria?(&1, filtros))
        |> Enum.map(&existencias_en_zona(&1, filtros))
        |> Enum.reject(&(map_size(&1.existencias) == 0))
        |> listar_texto(&Recurso.describir/1, "no se poseen recursos con esos filtros")

      error ->
        error
    end
  end

  defp despachar("movimientos", [codigo], _usuario) do
    InventarioServer.movimientos(codigo)
    |> listar_texto(&describir_movimiento/1, "no se tienen movimientos para el recurso #{codigo}")
  end

  #familias
  defp despachar("reportar_persona", [documento, nombre, edad, zona, estado], _usuario) do
    if ZonasServer.existe?(zona) do
      FamiliasServer.reportar(documento, nombre, Parser.entero(edad), zona, estado)
    else
      ubicacion_invalida(zona)
    end
  end

  # si no se especifica y se escribe solo un valor, por ejemplo "buscar_persona 123" entonces se toma como
  # si fuera "buscar_persona documento=123"
  defp despachar("buscar_persona", palabras, _usuario) do
    palabras = Enum.map(palabras, fn p -> if String.contains?(p, "="), do: p, else: "documento=" <> p end)
    permitidos = %{"documento" => :documento, "nombre" => :nombre, "zona" => :zona, "estado" => :estado}

    case preparar_filtros(palabras, permitidos) do
      {:ok, filtros} ->
        FamiliasServer.listar_personas()
        |> Enum.filter(&cumple?(&1, filtros))
        |> listar_texto(&Persona.describir/1, "no se tienen personas con esos datos")

      error ->
        error
    end
  end

  defp despachar("historial_persona", [documento], _usuario) do
    case FamiliasServer.obtener(documento) do
      {:ok, persona} ->
        historial = Enum.map_join(persona.historial, "\n", &Persona.describir_cambio/1)
        {:ok, Persona.describir(persona) <> "\nAsi ha cambiado su estado:\n" <> historial}

      error ->
        error
    end
  end

  defp despachar("actualizar_persona", [documento, estado], _usuario),
    do: FamiliasServer.actualizar_manual(documento, estado)

  defp despachar("enviar_mensaje", [documento, contenido], usuario),
    do: FamiliasServer.enviar_mensaje(usuario, documento, contenido)

  defp despachar("listar_mensajes", [documento], _usuario) do
    FamiliasServer.mensajes_de(documento)
    |> listar_texto(&Mensaje.describir/1, "no se tieenen mensajes para el documento #{documento}")
  end

  defp despachar("marcar_mensaje", [id, estado], _usuario),
    do: FamiliasServer.marcar_mensaje(id, estado)

  #albergues
  defp despachar("registrar_albergue", [codigo, nombre, zona, capacidad], _usuario) do
    cond do
      not codigo_libre?(codigo) -> codigo_ocupado(codigo)
      not ZonasServer.existe?(zona) -> ubicacion_invalida(zona)
      true -> AlberguesServer.registrar(codigo, nombre, zona, Parser.entero(capacidad))
    end
  end

  defp despachar("consultar_albergue", [codigo], _usuario) do
    case AlberguesServer.obtener(codigo) do
      {:ok, albergue} -> {:ok, detalle_albergue(albergue)}
      error -> error
    end
  end

  defp despachar("registrar_ingreso", [codigo, documento], _usuario),
    do: AlberguesServer.ingreso(codigo, documento)

  defp despachar("registrar_salida", [codigo, documento, estado], _usuario),
    do: AlberguesServer.salida(codigo, documento, estado)

  # los albergues se muestran en orden segun el mas ocupado al que lo este menos
  defp despachar("reporte_albergues", [], _usuario) do
    AlberguesServer.listar()
    |> Enum.sort_by(&Albergue.porcentaje/1, :desc)
    |> listar_texto(&Albergue.describir/1, "no se tienen albergues registrados de momento")
  end

  defp despachar("recursos_criticos", [], _usuario), do: {:ok, recursos_criticos()}

  # crea una tarea (Task) por cada necesidad y las ejecuta todas al mismo tiempo
  # sobre el mismo recurso, para ver que pasa cuando varias piden al mismo tiempo.
  defp despachar("simular_asignacion", [codigo, ubicacion | ids], _usuario) when ids != [] do
    resultados =
      ids
      |> Enum.map(fn id -> Task.async(fn -> {id, NecesidadesServer.asignar(id, codigo, ubicacion)} end) end)
      |> Enum.map(&Task.await/1)

    lineas =
      Enum.map_join(resultados, "\n", fn {id, {resultado, texto}} -> "  #{id} -> #{resultado_simulacion(resultado)}: #{texto}" end)

    {:ok, "se enviaron #{length(ids)} solicitudes a la vez por #{codigo} en #{ubicacion}. aqui esta el resultado de cada una:\n" <> lineas}
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
  # un sector, un punto de atención o un albergue.
  defp ubicacion_valida?(codigo), do: ZonasServer.existe?(codigo) or AlberguesServer.existe?(codigo)

  # Revisa si un código está libre, es decir, que ninguna zona, sector, punto ni albergue lo use
  defp codigo_libre?(codigo), do: not ubicacion_valida?(codigo)

  # Mensajes de error que se repiten en varios comandos
  defp ubicacion_invalida(codigo), do: {:error, "no existe ninguna zona, sector, punto o albergue con el codigo #{codigo}"}

  defp codigo_ocupado(codigo), do: {:error, "el codigo #{codigo} se encuentra ocupado, debe escojerse otro"}

  # Devuelve un MapSet con los códigos de la zona, de sus sectores y puntos (se recorre de
  # forma recursiva) y también los códigos de los albergues que están en esas ubicaciones.
  defp ubicaciones_de(zona) do
    codigos = MapSet.new(Zona.codigos(zona))
    albergues = for a <- AlberguesServer.listar(), MapSet.member?(codigos, a.zona), do: a.codigo
    MapSet.union(codigos, MapSet.new(albergues))
  end

  # Revisa los filtros con Parser.filtros y, si viene el filtro zona=X, lo cambia por el
  # conjunto de ubicaciones que hay dentro de X.
  defp preparar_filtros(palabras, permitidos) do
    case Parser.filtros(palabras, permitidos) do
      {:ok, filtros} -> convertir_zona(filtros)
      error -> error
    end
  end

  # Si hay un filtro de zona, busca esa zona y cambia su código por todas las ubicaciones
  # que tiene adentro. Si la zona no existe devuelve el error.
  defp convertir_zona(filtros) do
    case List.keyfind(filtros, :zona, 0) do
      nil ->
        {:ok, filtros}

      {:zona, codigo} ->
        case ZonasServer.obtener(codigo) do
          {:ok, zona} -> {:ok, List.keyreplace(filtros, :zona, 0, {:zona, ubicaciones_de(zona)})}
          error -> error
        end
    end
  end

  # Devuelve true si el elemento cumple todos los filtros. El nombre se busca sin
  # importar si está en mayúsculas o minúsculas.
  defp cumple?(elemento, filtros) do
    Enum.all?(filtros, fn
      {:zona, ubicaciones} -> MapSet.member?(ubicaciones, elemento.zona)
      {:nombre, texto} -> String.contains?(String.downcase(elemento.nombre), String.downcase(texto))
      {campo, valor} -> Map.get(elemento, campo) == valor
    end)
  end

  # Devuelve true si no hay filtro de categoría o si el recurso es de esa categoría
  defp cumple_categoria?(recurso, filtros) do
    case List.keyfind(filtros, :categoria, 0) do
      nil -> true
      {:categoria, categoria} -> recurso.categoria == categoria
    end
  end

  # Si hay filtro de zona, deja solo las existencias que están dentro de esa zona.
  # Si no hay filtro, devuelve el recurso igual.
  defp existencias_en_zona(recurso, filtros) do
    case List.keyfind(filtros, :zona, 0) do
      nil ->
        recurso

      {:zona, ubicaciones} ->
        existencias = Map.filter(recurso.existencias, fn {ubicacion, _cantidad} -> MapSet.member?(ubicaciones, ubicacion) end)
        %{recurso | existencias: existencias}
    end
  end

  # Convierte cada elemento de la lista en una línea de texto usando la función describir.
  # Si la lista está vacía devuelve mensaje_vacio.
  defp listar_texto([], _describir, mensaje_vacio), do: {:ok, mensaje_vacio}
  defp listar_texto(lista, describir, _mensaje_vacio), do: {:ok, Enum.map_join(lista, "\n", describir)}

  # Cambia el resultado de cada solicitud de la simulación por una palabra fácil de leer
  defp resultado_simulacion(:ok), do: "se asigno"
  defp resultado_simulacion(:error), do: "no se pudo asignar"

  # Une los elementos de la lista separados por comas. Si la lista está vacía
  # devuelve "nada por ahora".
  defp lista_o_ninguno([]), do: "nada por ahora"
  defp lista_o_ninguno(lista), do: Enum.join(lista, ", ")

  # Arma una línea de texto con los datos de un movimiento del inventario, separados por |
  defp describir_movimiento({fecha, codigo, tipo, ubicacion, cantidad, detalle}),
    do: "#{fecha} | #{codigo} | #{tipo} | #{ubicacion} | #{cantidad} | #{detalle}"

  # Arma el reporte de un albergue con su ocupación, las personas que están adentro,
  # sus necesidades y los recursos que tiene guardados.
  defp detalle_albergue(albergue) do
    necesidades = for n <- NecesidadesServer.listar(), n.zona == albergue.codigo, do: n.id

    recursos =
      for r <- InventarioServer.listar(),
          Recurso.disponible(r, albergue.codigo) > 0,
          do: "#{r.codigo}: #{Recurso.disponible(r, albergue.codigo)} #{r.unidad}"

    Albergue.describir(albergue) <>
      "\npersonas adentro: #{lista_o_ninguno(Enum.to_list(albergue.personas))}" <>
      "\nnecesidades: #{lista_o_ninguno(necesidades)}" <>
      "\nrecursos guardados: #{lista_o_ninguno(recursos)}"
  end

  # Un recurso es crítico cuando lo que hay en el inventario no alcanza para las necesidades
  # pendientes de ese tipo. Suma lo disponible por categoría, suma lo que se necesita por
  # tipo y compara los dos valores.
  defp recursos_criticos do
    disponible =
      InventarioServer.listar()
      |> Enum.group_by(& &1.categoria, &Recurso.total/1)
      |> Map.new(fn {categoria, totales} -> {categoria, Enum.sum(totales)} end)

    criticos =
      NecesidadesServer.listar()
      |> Enum.filter(&(&1.estado == "pendiente"))
      |> Enum.group_by(& &1.tipo, & &1.cantidad)
      |> Enum.map(fn {tipo, cantidades} -> {tipo, Enum.sum(cantidades), Map.get(disponible, tipo, 0)} end)
      |> Enum.filter(fn {_tipo, requerido, hay} -> hay < requerido end)

    case criticos do
      [] ->
        "de momento, los recursos son suficientes para las necesidades pendientes"

      _ ->
        "los recursos no alcanzan para estas necesidades  que tenemos pendientes:\n" <>
          Enum.map_join(criticos, "\n", fn {tipo, requerido, hay} -> "  #{tipo}: se necesitan #{requerido} y solo tenemos #{hay}" end)
    end
  end
end
