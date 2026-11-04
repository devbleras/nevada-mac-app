# Nevada ❄︎

Una app navideña para macOS que hace nevar sobre tu escritorio. Los copos caen por delante de todo y la nieve se va amontonando poco a poco sobre las ventanas, los widgets, la barra de menús, el Dock y el borde inferior de la pantalla.

- Si mueves o cierras una ventana, la nieve que tenía encima se cae.
- Los copos se apartan al pasar el cursor.
- No molesta: los clics atraviesan la nieve y la app vive en la barra de menús, sin icono en el Dock.
- Funciona con varias pantallas, en todos los escritorios y con apps a pantalla completa.

## Requisitos

- macOS 14 Sonoma o posterior.
- Mac con Apple Silicon o Intel.

## Instalación

1. Descarga `Nevada.zip` desde la página de [Releases](https://github.com/devbleras/nevada-mac-app/releases).
2. Descomprímelo y arrastra **Nevada** a la carpeta **Aplicaciones**.
3. Ábrela. Aparecerá un copo ❄︎ en la barra de menús.

**La primera vez macOS la bloqueará.** Nevada no está firmada con un certificado de Apple Developer, así que la primera vez macOS dice que no puede verificar al desarrollador. Para abrirla:

- Ve a **Ajustes del Sistema → Privacidad y seguridad**, baja hasta el aviso sobre Nevada y pulsa **Abrir igualmente**.
- O, si lo prefieres, en Terminal:

  ```bash
  xattr -dr com.apple.quarantine /Applications/Nevada.app
  ```

Si no te fías de un binario descargado (es lo sensato), puedes compilarla tú mismo desde el código. Te explico cómo más abajo.

## Uso

Haz clic en el copo de la barra de menús para:

- Encender o apagar la nieve.
- Ajustar la cantidad de copos, el viento y el tamaño de los copos.
- Activar o desactivar la acumulación y elegir su velocidad.
- Activar o desactivar la nieve en la barra de menús.
- Hacer que los copos esquiven el cursor.
- **Barrer la nieve** acumulada.
- Abrir Nevada al iniciar sesión.

Cuando apagas la nieve, lo acumulado se derrite y la animación se detiene para no gastar batería.

## Permisos y privacidad

- **No se conecta a internet** y no recopila ni envía ningún dato.
- Para saber dónde posar la nieve, lee **solo la posición y el tamaño** de las ventanas visibles. No ve su contenido y no necesita permiso de grabación de pantalla.
- **Accesibilidad (opcional):** solo hace falta si quieres que la nieve se pose sobre el Dock. Nevada lo usa únicamente para saber el tamaño del Dock. Puedes concederlo desde el propio panel de la app.

## Compilar desde el código

Necesitas las herramientas de línea de comandos de Xcode (o Xcode 16 o posterior).

```bash
git clone https://github.com/devbleras/nevada-mac-app.git
cd nevada-mac-app
./build.sh
open build/Nevada.app
```

`build.sh` compila para Apple Silicon e Intel y genera `build/Nevada.app` y `build/Nevada.zip`. También puedes abrir `Package.swift` con Xcode.

### Estructura

| Archivo | Qué hace |
| --- | --- |
| `NevadaApp.swift` | App de barra de menús y panel de ajustes |
| `OverlayController.swift` | Una capa transparente por pantalla, por encima de todo y sin capturar clics |
| `SnowScene.swift` | Simulación de los copos, el viento, el cursor y los choques con las superficies |
| `SnowPile.swift` | Cada montón de nieve: mapa de alturas, deslizamiento, deshielo y dibujo |
| `WindowTracker.swift` | Posición de ventanas, widgets y Dock |
| `SnowTextures.swift` | Texturas de los copos generadas en código |

## Licencia

[MIT](LICENSE): úsala, modifícala y compártela libremente.
