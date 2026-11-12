defmodule ComandosTest do
  use ExUnit.Case


  #esstaria revisando que el sistema haga el rechazo a lo que no se debe dejar, como usar comandos sin sesion, un ciudadano
  # registra las zonas, una clave que esta mal, registrarse solo como coordinadores, comandos o los filtros que no existen
  test "permisos y validaciones de usuarios" do
    falla("listar_zonas", nil)
    samuel = ok("conectar samuel 1111", nil)
    falla("registrar_zona z9 Z9 bajo 1", samuel)
    falla("conectar samuel otra_clave", nil)



    falla(~s(conectar isabel 1 coordinador centro "Isabel Cristina"), nil)
    falla("comando_que_no_existe", samuel)
    falla("listar_necesidades color=rojo", samuel)
  end


  defp ok(linea, usuario) do
    {nuevo_usuario, respuesta} = Comandos.ejecutar(linea, usuario)
    assert {:ok, _texto} = respuesta
    nuevo_usuario


  end

  defp falla(linea, usuario) do
    {_usuario, respuesta} = Comandos.ejecutar(linea, usuario)
    assert {:error, _texto} = respuesta

  end
end
