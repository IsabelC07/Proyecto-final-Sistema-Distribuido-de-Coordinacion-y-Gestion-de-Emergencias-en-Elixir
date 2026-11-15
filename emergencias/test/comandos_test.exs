defmodule ComandosTest do
  use ExUnit.Case


  # aqui probamos los comandos, recorre el flujo de ejemplo del enunciado escribiendo los comandos en consola,
  # zonas, necesidad, recurso, albergue, persona, mensaje, mascotas y ademas de reportes. todos deberian de salir
  test "inicio del test 1 que son comandos test" do
    admin = ok("conectar admin admin", nil)
    ok(~s(crear_usuario simon 1234 coordinador centro "Simon Valencia"), admin)
    simon = ok("conectar simon 1234", admin)
    ok(~s(registrar_zona centro "Zona Centro" critico 500), simon)
    ok(~s(registrar_sector centro sector3 "Sector 3" alto 200), simon)
    ok(~s(registrar_punto sector3 centro_acopio_1 "Centro de acopio 1" medio 0), simon)
    ok(~s(registrar_necesidad agua 30 critica sector3 "Punto de atencion sector 3"), simon)
    id = List.last(NecesidadesServer.listar()).id
    ok(~s(registrar_recurso R001 "Agua potable" agua 50 litros centro_acopio_1), simon)
    ok("asignar_recurso #{id} R001 centro_acopio_1", simon)
    ok("listar_necesidades zona=centro prioridad=critica", simon)



    ok(~s(registrar_albergue A01 "Albergue Norte" centro 150), simon)
    ok(~s(reportar_persona 1001 "Isabel Cristina" 34 centro localizada), simon)
    ok("registrar_ingreso A01 1001", simon)
    ok(~s(enviar_mensaje 1001 "Estoy bien, estoy en el albergue norte"), simon)
    ok(~s(reportar_mascota perdida perro Luna negra mediana centro 3001234567 "collar rojo"), simon)
    ok(~s(reportar_mascota encontrada perro desconocido negra mediana centro 3007654321 "collar rojo"), simon)
    ok("buscar_coincidencias", simon)
    ok("estado_zona centro", simon)
    ok("resumen", simon)
    ok("recursos_criticos", simon)
  end

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
