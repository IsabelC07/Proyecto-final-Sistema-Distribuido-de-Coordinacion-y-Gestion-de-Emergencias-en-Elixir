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

# Datos

todo se guarda en archivos de texto dentro de la carpeta data/, que se crea sola, cuando hacemos correr todo esto
para volver a comprobar todo, borra la carpeta data/.
