# esto es porque cada vez que se ejecuta un test, se reinicia la aplicacion y se borra la carpeta data_test para que no haya conflictos con los datos de los tests anteriores
Application.stop(:emergencias)
File.rm_rf!("data_test")
{:ok, _} = Application.ensure_all_started(:emergencias)


ExUnit.start()
