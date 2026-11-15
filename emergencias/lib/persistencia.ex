defmodule Persistencia do
  @moduledoc """
  este unico modulo lee y escribe archivos. lo separamos y solo se encarga de eso, los demas modulos solo le pasan datos.


  todos los archivos de texto tienen una primera linea con los titulos de las colomnas y despues una linea por registro
  usa '|' como el separador porque las descripciones pueden tener comillas y es un caracter poco comun y no deberia
  chocar con nada de lo que tenemos

  los archivos se guardan en la carpeta data (o en la que indique la
  configuración `:directorio`, por ejemplo `data_test` para lo que son las pruebas).

  Autores: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán
  Licencia: GNU GPL v3
  """
  @separador "|"

  # usuarios

  @doc "Guarda todos los usuarios en usuarios.txt (entonces remplaza el archivo)."
  def guardar_usuarios(usuarios) do
    escribir("usuarios.txt", "usuario|clave|nombre|tipo|zona", Map.values(usuarios), fn u ->
      [u.usuario, u.clave, u.nombre, u.tipo, u.zona]
    end)
  end

  @doc "lee usuarios.txt y entonces devuelve un mapa asi= `%{nombre_usuario => %Usuario{}}`"
  def cargar_usuarios do
    leer("usuarios.txt", fn [usuario, clave, nombre, tipo, zona] ->
      %Usuario{usuario: usuario, clave: clave, nombre: nombre, tipo: tipo, zona: zona}
    end)
    |> Map.new(fn u -> {u.usuario, u} end)
  end

  # Zonas
  # el arbol se esta guardando plano, cada linea indica el codigo de el padre

  @doc "esta guardando el arbol de zonas en zonas.txt. cada linea indica el codigo de el padre"
  def guardar_zonas(zonas) do
    escribir("zonas.txt", "codigo|nombre|tipo|nivel|afectados|padre", aplanar(zonas, ""), fn {z, padre} ->
      [z.codigo, z.nombre, z.tipo, z.nivel, z.afectados, padre]
    end)
  end



  @doc "lee zonas txt y vuelve a armar el arbol de las zonas, los sectores y puntos"
  def cargar_zonas do
    leer("zonas.txt", fn [codigo, nombre, tipo, nivel, afectados, padre] ->
      zona = %Zona{codigo: codigo, nombre: nombre, tipo: tipo, nivel: nivel, afectados: String.to_integer(afectados)}
      {zona, padre}
    end)
    |> armar_arbol("")
  end

  # aqui teneemos algo recursivo, conveirte el arbol en una lista de {zona, codigo_del_padre}
  defp aplanar([], _padre), do: []

  defp aplanar([zona | resto], padre),
    do: [{zona, padre}] ++ aplanar(zona.hijos, zona.codigo) ++ aplanar(resto, padre)

  # otra recursividad, donde recontruye el arbol buscando los hijos de cada padre
  defp armar_arbol(planas, padre) do
    planas
    |> Enum.filter(fn {_zona, codigo_padre} -> codigo_padre == padre end)
    |> Enum.map(fn {zona, _codigo_padre} -> %{zona | hijos: armar_arbol(planas, zona.codigo)} end)
  end

  # necesidades

  @doc "esta encargada de guardar toda las necedades en necesidades.txt y remplaza si ya se teneia uno"
  def guardar_necesidades(necesidades) do
    titulos = "id|tipo|cantidad|prioridad|zona|descripcion|responsable|estado|recurso|fecha"

    escribir("necesidades.txt", titulos, Map.values(necesidades), fn n ->
      [n.id, n.tipo, n.cantidad, n.prioridad, n.zona, n.descripcion, n.responsable, n.estado, n.recurso, n.fecha]
    end)
  end

  @doc "lee necesidades.txt y devuelve el mapa= `%{id => %Necesidad{}}`"
  def cargar_necesidades do
    leer("necesidades.txt", fn [id, tipo, cantidad, prioridad, zona, descripcion, responsable, estado, recurso, fecha] ->
      %Necesidad{
        id: id,
        tipo: tipo,
        cantidad: String.to_integer(cantidad),
        prioridad: prioridad,
        zona: zona,
        descripcion: descripcion,
        responsable: responsable,
        estado: estado,
        recurso: recurso,
        fecha: fecha
      }
    end)
    |> Map.new(fn n -> {n.id, n} end)
  end


  # recursos
  # recursos.txt esta guardando los datos de los recursos y existencias.txt cuanto hay en cada ubicacion.

  @doc """
  guarda los recursos en dos archivos distintos: recursos.txt (datos del recurso)
  y existencias.txt (cuanto tiene  en cada ubicacion).
  """
  def guardar_recursos(recursos) do
    lista = Map.values(recursos)

    escribir("recursos.txt", "codigo|nombre|categoria|unidad", lista, fn r ->
      [r.codigo, r.nombre, r.categoria, r.unidad]
    end)

    existencias = for r <- lista, {ubicacion, cantidad} <- r.existencias, do: [r.codigo, ubicacion, cantidad]
    escribir("existencias.txt", "codigo|ubicacion|cantidad", existencias, fn campos -> campos end)
  end

  @doc "lee recursos.txt y existencias.txt, despues devuelve un mapa `%{codigo => %Recurso{}}`"
  def cargar_recursos do
    existencias =
      leer("existencias.txt", fn [codigo, ubicacion, cantidad] ->
        {codigo, ubicacion, String.to_integer(cantidad)}
      end)

    leer("recursos.txt", fn [codigo, nombre, categoria, unidad] ->
      propias =
        existencias
        |> Enum.filter(fn {codigo_existencia, _ubicacion, _cantidad} -> codigo_existencia == codigo end)
        |> Map.new(fn {_codigo, ubicacion, cantidad} -> {ubicacion, cantidad} end)

      %Recurso{codigo: codigo, nombre: nombre, categoria: categoria, unidad: unidad, existencias: propias}
    end)
    |> Map.new(fn r -> {r.codigo, r} end)
  end

  @doc """
  agrega un movimiento al final de movimiento.txt
  el movimiento viene siendo una tupla `{fecha, codigo, tipo, ubicacion, cantidad, detalle}`
  """
  def agregar_movimiento({fecha, codigo, tipo, ubicacion, cantidad, detalle}) do
    agregar("movimientos.txt", "fecha|codigo|tipo|ubicacion|cantidad|detalle", [
      fecha,
      codigo,
      tipo,
      ubicacion,
      cantidad,
      detalle
    ])
  end

  @doc "Lee movimientos.txt y devuelve la lista de movimientos en el orden en que ocurrieron.
  lee movimientos.txt y devuelve la lista de movimientos en el orden en que ocurrieron, ordenadamente"
  def cargar_movimientos do
    leer("movimientos.txt", fn [fecha, codigo, tipo, ubicacion, cantidad, detalle] ->
      {fecha, codigo, tipo, ubicacion, String.to_integer(cantidad), detalle}
    end)
  end

  # personas y mensajes

  @doc "esta guarda todas las personas en personas.txt (sin el historial, que va en otro archivo distinto)"
  def guardar_personas(personas) do
    escribir("personas.txt", "id|documento|nombre|edad|zona|estado", Map.values(personas), fn p ->
      [p.id, p.documento, p.nombre, p.edad, p.zona, p.estado]
    end)
  end

  @doc "agrega el cambio actual de estado de una persona al final de historial_personas.txt"
  def agregar_cambio_persona(documento, {fecha, anterior, nuevo}) do
    agregar("historial_personas.txt", "documento|fecha|anterior|nuevo", [documento, fecha, anterior, nuevo])
  end

  @doc """
  lee persona.txt y historial_persona.txt, luego devulve un mapa de forma`%{documento => %Persona{}}` con el historial de la persona
  """
  def cargar_personas do
    historial =
      leer("historial_personas.txt", fn [documento, fecha, anterior, nuevo] ->
        {documento, {fecha, anterior, nuevo}}
      end)

    leer("personas.txt", fn [id, documento, nombre, edad, zona, estado] ->
      cambios =
        historial
        |> Enum.filter(fn {documento_cambio, _cambio} -> documento_cambio == documento end)
        |> Enum.map(fn {_documento, cambio} -> cambio end)

      %Persona{
        id: id,
        documento: documento,
        nombre: nombre,
        edad: String.to_integer(edad),
        zona: zona,
        estado: estado,
        historial: cambios
      }
    end)
    |> Map.new(fn p -> {p.documento, p} end)
  end

  @doc "guarda los mensajes en el archivo mensajes.txt (remplaza el archivo)"
  def guardar_mensajes(mensajes) do
    escribir("mensajes.txt", "id|fecha|remitente|destinatario|contenido|estado", Map.values(mensajes), fn m ->
      [m.id, m.fecha, m.remitente, m.destinatario, m.contenido, m.estado]
    end)
  end

  @doc "Lee mensajes.txt y devuelve un mapa `%{id => %Mensaje{}}`."
  def cargar_mensajes do
    leer("mensajes.txt", fn [id, fecha, remitente, destinatario, contenido, estado] ->
      %Mensaje{id: id, fecha: fecha, remitente: remitente, destinatario: destinatario, contenido: contenido, estado: estado}
    end)
    |> Map.new(fn m -> {m.id, m} end)
  end

  # mascotas

  @doc "guarda todos los reportes de mascotas en la mascota.txt (esto remplaza el archivo)"
  def guardar_mascotas(mascotas) do
    titulos = "id|tipo|especie|nombre|color|tamano|zona|contacto|estado|coincidencia|caracteristicas"

    escribir("mascotas.txt", titulos, Map.values(mascotas), fn m ->
      [m.id, m.tipo, m.especie, m.nombre, m.color, m.tamano, m.zona, m.contacto, m.estado, m.coincidencia, m.caracteristicas]
    end)
  end


  @doc "lee mascotas.txt y devuelve un mapa `%{id => %Mascota{}}`."
  def cargar_mascotas do
    leer("mascotas.txt", fn [id, tipo, especie, nombre, color, tamano, zona, contacto, estado, coincidencia, caracteristicas] ->
      %Mascota{
        id: id,
        tipo: tipo,
        especie: especie,
        nombre: nombre,
        color: color,
        tamano: tamano,
        zona: zona,
        contacto: contacto,
        estado: estado,
        coincidencia: coincidencia,
        caracteristicas: caracteristicas
      }
    end)
    |> Map.new(fn m -> {m.id, m} end)
  end

  # albergues
  #los documentos de las personas dentro de los albergues se estarian guardando de forma separada.

  @doc "guarda los albergues en albergues.txt (reemplaza el archivo)"
  def guardar_albergues(albergues) do
    escribir("albergues.txt", "codigo|nombre|zona|capacidad|personas", Map.values(albergues), fn a ->
      [a.codigo, a.nombre, a.zona, a.capacidad, Enum.join(a.personas, ",")]
    end)
  end

  @doc "lee albergues.txt, despues devuelve un mapa `%{codigo => %Albergue{}}`"
  def cargar_albergues do
    leer("albergues.txt", fn [codigo, nombre, zona, capacidad, personas] ->
      %Albergue{
        codigo: codigo,
        nombre: nombre,
        zona: zona,
        capacidad: String.to_integer(capacidad),
        personas: MapSet.new(String.split(personas, ",", trim: true))
      }
    end)
    |> Map.new(fn a -> {a.codigo, a} end)
  end

  # Actividad de usuarios

  @doc """

  agrega una linea a actividade.txt con la fecha, el usuario, la accion y el resultado (:ok o error). ese usa la bitacora
  """
  def registrar_actividad(usuario, accion, resultado) do
    agregar("actividad.txt", "fecha|usuario|accion|resultado", [Util.fecha_actual(), usuario, accion, resultado])
  end

  # funciones generales

  # con lo que vimos del modulo Csv en clase (escribir_csv / leer_csv), creamos esto.

  # reescribe todo el archivo: titulo mas una linea por elemento
  defp escribir(archivo, titulos, elementos, a_campos) do
    File.mkdir_p!(directorio())
    lineas = Enum.map(elementos, fn elemento -> unir(a_campos.(elemento)) end)
    File.write!(ruta(archivo), Enum.join([titulos | lineas], "\n"))
  end



  #lee el archivo saltando por los titulos; si no existe solo da una lista vacia
  defp leer(archivo, a_elemento) do
    if File.exists?(ruta(archivo)) do
      File.stream!(ruta(archivo))
      |> Enum.drop(1)
      |> Enum.map(&String.trim_trailing/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn texto -> a_elemento.(String.split(texto, @separador)) end)
    else
      []
    end
  end
  # agrega una linea al final del archivo (para lo que es el historial)
  defp agregar(archivo, titulos, campos) do
    File.mkdir_p!(directorio())

    if not File.exists?(ruta(archivo)) do
      File.write!(ruta(archivo), titulos <> "\n")
    end

    File.write!(ruta(archivo), unir(campos) <> "\n", [:append])
  end



  # se encarga de unir los campos con el separador. Si un texto trae "|" se cambia por "/" para no dañar el archivo
  defp unir(campos) do
    campos
    |> Enum.map(fn campo -> String.replace(to_string(campo), @separador, "/") end)
    |> Enum.join(@separador)
  end


  # ruta completa del archivo dentro de la carpeta de los datos
  defp ruta(archivo), do: Path.join(directorio(), archivo)




  #carpeta de datos: "data" por defecto, o la indicada en lo que es la configuracion
  defp directorio, do: Application.get_env(:emergencias, :directorio, "data")
end
