# Sistema de Coordinación y Gestión de Emergencias

Proyecto final de Programacion 3 Universidad del Quindio.

Integrantes: Simón Valencia Ochoa, Samuel Marín Varón e Isabel Cristina Guerra Guzmán.

# Requisitos

Elixir 1.15 o superior (`elixir --version` para verificar). Nosotros usamos Elixir 1.20.4.

# Como
abrimos una terminal dentro de la carpeta `emergencias` y usar:

|        Para        |   En PowerShell   | En CMD, Git Bash, Linux |
| Iniciar el sistema | mix.bat consola   |         mix consola     |
| Correr las pruebas | mix.bat test      |         mix test        |


ya en lo que viene ciendo la consola:

`conectar admin admin` -> entra con el administrador que se crea la primera vez
`ayuda` -> muestra todos los comandos y como se escriben
`salir` -> cierra el sistema

si un usuario no existe, `conectar usuario clave` lo registra solo (esto como ciudadano).
los textos con espacios van entre comillas, por ejemplo "Albergue Norte".

# Demostracion

hacemos una demostraccion de como seria usado este sistema en caso de terremoto, haciendo pruebas que abarcan todas las funciones. Antes de empezar,
**borra la carpeta `data/`** para que los códigos salgan igual que aquí (N001, MS001, MA001...) y no interfiera data pasada o anteriores ejecuciones de esta demostracion.
Abre el sistema con `mix.bat consola` y escribe los bloques en orden, uno por uno y sin salirse.

Casi todo se hace con el `admin`, que tiene permiso para todo. algunas lineas que especificamos
deben fallar a propósito: asi se ve que el sistema valida los datos y no deja hacer trampas.

 1. usuarios

conectar admin admin
ayuda
crear_usuario simon 1234 coordinador centro "Simon Valencia"
crear_usuario simon 5555 voluntario norte "Simon Otro"

-  El segundo crear_usuario falla: el nombre de usuario `simon` ya existe (como es identificador nose repetiria, podria por ejemplo poner una inicial del apellido).

 2. zonas afectadas (de zona a sector, y luego a  punto de atención)

registrar_zona centro "Centro de Armenia" critico 1287
registrar_zona norte "Norte de Armenia" alto 643
registrar_sector centro laisla "Barrio La Isla" critico 418
registrar_sector norte cecilia "Barrio La Cecilia" medio 156
registrar_punto laisla parque_sucre "Parque Sucre" alto 73
registrar_punto cecilia coliseo "Coliseo del Cafe" medio 0
registrar_zona centro "Centro repetido" bajo 12
listar_zonas

- La zona centro ya existe, no se puede registrar dos veces.
- listar_zonas muestra el arbol completo (se recorre con recursividad).

 3. albergues y recursos

registrar_albergue A01 "Albergue Norte" cecilia 3
registrar_albergue A02 "Escuela La Isla" laisla 45
registrar_recurso R001 "Agua potable" agua 50 litros coliseo
registrar_recurso R002 "Mercados familiares" alimentos 136 cajas coliseo
registrar_recurso R003 "Botiquines" primeros_auxilios 24 kits coliseo
registrar_recurso R001 "Agua en bolsa" agua 80 litros coliseo
entrada_recurso R002 coliseo 37
salida_recurso R002 coliseo 12
salida_recurso R003 coliseo 30
transferir_recurso R002 coliseo A01 45
transferir_recurso R003 coliseo A02 9
listar_recursos
listar_recursos categoria=agua
listar_recursos zona=norte
movimientos R002

- El Coliseo del Cafe funcionaria como centro de acopio.
- El recurso R001 ya existe.
- No se pueden sacar 30 botiquines si solo hay 24 (se tienen restricciones para que el inventario no sea negativo).
- movimientos muestra el historial de entradas, salidas y transferencias.

4. necesidades y conflicto concurrente

registrar_necesidad alimentos 18 media A01 "Familias recien llegadas al albergue"
registrar_necesidad agua 30 critica parque_sucre "Punto de atencion del Parque Sucre"
registrar_necesidad agua 25 alta laisla "Familias sin servicio de agua en La Isla"
registrar_necesidad medicamentos 7 baja centro "Medicamentos para la presion"
registrar_necesidad transporte 2 media norte "Traslado de dos adultos mayores"
registrar_necesidad agua -5 alta centro "Agua para el colegio"
listar_necesidades
listar_necesidades zona=centro prioridad=critica
listar_necesidades tipo=agua
recursos_criticos
simular_asignacion R001 coliseo N002 N003
listar_necesidades estado=pendiente
actualizar_necesidad N005 cancelada
asignar_recurso N001 R002 A01
actualizar_necesidad N001 en_atencion
actualizar_necesidad N001 atendida
asignar_recurso N001 R002 A01
actualizar_necesidad N001 atendida
necesidades_pendientes

- No se aceptan cantidades negativas.
- Las necesidades se registraron en desorden, pero listar_necesidades las muestra ordenadas por prioridad
  (crítica, alta, media, baja).
- recursos_criticos avisa que el agua no alcanza (se piden 55 litros y solo hay 50).
- El conflicto del enunciado: simular_asignacion manda las dos solicitudes al mismo tiempo sobre los
  mismos 50 litros. Una recibe sus litros y la otra se rechaza: nunca se asignan 55.
- La necesidad N005 se cancela, y N001 pasa por todos los estados: pendiente -> asignada -> en atención -> atendida.
- Una necesidad atendida no puede volver a recibir recursos ni cerrarse una segunda veces.

 5. personas afectadas y mensajes de familiares

reportar_persona 1094887321 "Andres Felipe Restrepo" 34 laisla localizada
reportar_persona 41927735 "Maria Fernanda Gomez" 61 cecilia reportada
reportar_persona 1097402118 "Jorge Ivan Salazar" 27 cecilia sin_informacion
reportar_persona 1005912384 "Valentina Rios" 9 laisla reportada
buscar_persona 1094887321
buscar_persona nombre=maria
buscar_persona zona=norte
buscar_persona estado=reportada
actualizar_persona 41927735 localizada
actualizar_persona 1005912384 reunificada
enviar_mensaje 1094887321 "Andres, somos tu mama y tu hermana. Estamos bien en Calarca, llamanos al 3104578923"
enviar_mensaje 1094887321 "Hijo, el abuelo tambien esta bien. Te esperamos"
listar_mensajes 1094887321
marcar_mensaje MS001 entregado

- Se busca por documento, nombre, zona y estado.
- Valentina no puede pasar de reportada a reunificada sin antes ser localizada (por el orden que siguen los estados)

 6. Albergues
registrar_ingreso A01 1094887321
registrar_ingreso A01 41927735
registrar_ingreso A01 1097402118
registrar_ingreso A01 1005912384
registrar_ingreso A02 1005912384
consultar_albergue A01
reporte_albergues
registrar_salida A01 1094887321 reunificada
historial_persona 1094887321

- el Albergue Norte tiene capacidad para 3 personas, así que Valentina no cabe y entra en la Escuela La Isla.
- reporte_albergues los ordena del más lleno al que esta mas vacio.
- Andrés sale reunificado con su familia, y su historial muestra cada cambio en los estado.

 7. Mascotas perdidas y encontradas

reportar_mascota perdida perro Lupe cafe mediana laisla 3157781204 "collar azul con placa"
reportar_mascota encontrada perro desconocido cafe mediana laisla 3008842271 "collar azul"
reportar_mascota perdida gato Misu blanco pequena cecilia 3124409983 "ojos de distinto color"
reportar_mascota encontrada gato desconocido gris pequena centro 3015568820 "muy asustado"
listar_mascotas
listar_mascotas especie=gato
buscar_coincidencias
listar_mascotas estado=posible_coincidencia
confirmar_coincidencia MA001 MA002
confirmar_coincidencia MA001 MA002
listar_mascotas zona=laisla

- buscar_coincidencias da puntaje por zona, color, tamaño, nombre y características. Lupe y el perro
  encontrado sacan 80 puntos; los gatos no se parecen lo suficiente.
- Al confirmar, los dos reportes quedan resueltos. No se pueden resolver dos veces.

 8. reportes generales

estado_zona centro
resumen

- estado_zona suma lo de la zona y todo lo que tiene por dentro (sectores y puntos).
- resumen muestra recursos restantes, necesidades, personas, mensajes, mascotas y albergues.

 9. Permisos según el tipo de usuario

desconectar
conectar simon 0000
conectar simon 1234
crear_usuario samuel 7777 voluntario norte "Samuel Marin"
desconectar
conectar isabel 2468
registrar_zona sur "Sur de Armenia" bajo 37
reportar_persona 1093221456 "Luis Carlos Mejia" 45 cecilia sin_informacion
salir

- es una clave incorrecta: no deja entrar.
- Simón es coordinador: hacer casi todo, pero solo un administrador crea usuarios.
- isabel no exitia, asi que queda registrada sola como ciudadana. un ciudadano no puede registrar zonas,
  pero sí puede reportar a una persona.

 10. Persistencia (cerrar y volver a abrir)
Abre otra vez con `mix.bat consola` y escribe:

conectar admin admin
resumen
salir

- El resumen sale igual que antes de cerrar: todo quedó guardado en los archivos de data/.
- Abre data/actividad.txt para mostrar la bitácora: ahí queda cada comando que usó cada usuario.

 11. Pruebas automáticas

mix.bat test

- Deben pasar las 20 pruebas, entre ellas las de concurrencia (por ejemplo, 20 solicitudes al mismo tiempo
  sobre 50 litros: solo se atienden 5).

# Datos

todo se guarda en archivos de texto dentro de la carpeta data/, que se crea sola, cuando hacemos correr todo esto
para volver a comprobar todo, borra la carpeta data/.
