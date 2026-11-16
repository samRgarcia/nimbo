# Nimbo

Clima vivo sobre el escritorio de tu Mac. La nieve se junta sobre las ventanas y el Dock,
la lluvia salpica en los bordes y la escena cambia sola según el clima real de tu ciudad.

## Instalar

Descarga [Nimbo.dmg](https://github.com/samRgarcia/nimbo/releases/latest/download/Nimbo.dmg),
ábrelo y arrastra Nimbo a Aplicaciones. Requiere macOS 14 o posterior.

La app es gratuita y todavía no está notarizada por Apple. La primera vez macOS la bloqueará:
ve a Ajustes del Sistema › Privacidad y seguridad y pulsa "Abrir igualmente".

## Compilar y abrir

```bash
./build-app.sh
```

Requiere macOS 14 o posterior y las herramientas de Xcode. La app queda en `build/Nimbo.app`
y aparece como un icono en la barra de menús.

## Qué hace

- **Diez escenas**: nieve, lluvia, pétalos, hojas, luciérnagas, meteoros, tormenta, nublado, neblina y despejado.
- **Clima real**: elige tu ciudad en Ajustes; se consulta Open-Meteo cada 15 minutos (sin clave)
  y se muestra el pronóstico de las próximas 24 horas.
- **Ventanas**: la nieve se acumula en el borde superior de cada ventana y cae al moverla o cerrarla.
  Pasa el cursor rápido por un montón para esparcirlo.
- **Taller de invierno** (menú): muñeco de nieve, árbol de Navidad con adornos, quitanieves y cabaña con chimenea.
- **Bolas de nieve**: mantén Opción y mueve el cursor sobre la nieve; apila tres para armar un muñeco.

## Rendimiento

- Las escenas tranquilas corren a 30 cuadros por segundo y las de caída rápida a 60.
- **Ahorro de energía** (o el modo de bajo consumo de macOS) baja todo a 30 cuadros y usa menos partículas.
- Se detiene sola con la pantalla apagada o la sesión bloqueada, y se oculta en apps a pantalla completa.

## Privacidad

Solo se envían a Open-Meteo las coordenadas redondeadas de la ciudad elegida.
La posición de las ventanas nunca sale de la Mac, y la app no pide permisos.

## Publicar una versión

```bash
bash release.sh
```

Genera el `.dmg` universal y lo sube a GitHub Releases. El número de versión sale de `Support/Info.plist`.

## Créditos

Datos del clima de [Open-Meteo](https://open-meteo.com/), bajo licencia CC BY 4.0.

## Estructura

| Archivo | Contenido |
| --- | --- |
| `NimboMain.swift` | Arranque, icono y menú de la barra |
| `Models.swift` | Escenas, estado guardado y códigos de clima |
| `WeatherService.swift` | Llamadas a Open-Meteo |
| `OverlayController.swift` | Ventanas transparentes por pantalla |
| `WeatherScene.swift` | Partículas, acumulación de nieve, ratón y taller |
| `Ledge.swift` | Repisas donde se junta la nieve |
| `WindowTracker.swift` | Posición de las ventanas |
| `Textures.swift`, `Decor.swift` | Texturas y adornos dibujados por código |
