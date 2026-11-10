# Inverto

Inverto es una aplicación desarrollada con Flutter para llevar un seguimiento sencillo de tus inversiones. Permite registrar el dinero que aportas y actualizar manualmente el valor de tu fondo para consultar su evolución.

Puedes usarla para:

- Crear y renombrar varios fondos, cada uno con sus propias aportaciones, valoraciones e historial.
- Registrar aportaciones y consultar su historial en un calendario.
- Ver el capital aportado y el valor actual de la inversión.
- Consultar las ganancias o pérdidas y la rentabilidad total y diaria.
- Visualizar en un gráfico la evolución de las ganancias o pérdidas diarias.
- Eliminar aportaciones o reiniciar los datos del fondo seleccionado para empezar de nuevo.

Los datos se guardan localmente en el dispositivo y se conservan al cerrar la aplicación. Las aportaciones y las valoraciones se introducen manualmente.

La interfaz está adaptada a móviles Android, con un calendario amplio, tarjetas de resumen y un icono propio. Incluye la tipografía [Inter](https://github.com/rsms/inter), distribuida bajo la licencia SIL Open Font License que se conserva en `assets/fonts/OFL.txt`.

Para generar un APK instalable con Flutter y el SDK de Android configurados:

```sh
flutter pub get
flutter build apk --release
```

El archivo se genera en `build/app/outputs/flutter-apk/app-release.apk`. La configuración actual usa la firma de desarrollo para instalación personal. Para distribuir la aplicación en una tienda se debe configurar una firma de publicación.
