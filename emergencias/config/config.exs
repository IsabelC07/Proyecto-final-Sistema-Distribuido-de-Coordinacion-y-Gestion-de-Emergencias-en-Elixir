import Config

# dice la carpeta que guarda los archivos de texto. diferencia de un test de el codigo corriendo para que no se borren los datos reales.
config :emergencias, directorio: if(config_env() == :test, do: "data_test", else: "data")
