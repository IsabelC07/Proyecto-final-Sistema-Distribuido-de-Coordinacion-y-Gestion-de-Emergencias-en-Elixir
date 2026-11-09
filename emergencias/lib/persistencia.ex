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
