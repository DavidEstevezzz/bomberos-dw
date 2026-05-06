{% docs categoria_puesto %}

Categoría agregada del puesto operativo del bombero. Derivada del campo `puesto` mediante esta regla:

| Puesto operativo                | Categoría        |
|---------------------------------|------------------|
| Conductor, Operador, Bombero    | **Tropa**        |
| Subinspector, Oficial           | **Mando**        |
| (puesto NULL)                   | **Administrativo** |
| Cualquier otro                  | **Desconocido**  |

**Importancia analítica**: la `categoria_puesto` determina la tarifa salarial aplicable a las horas extra. La Tropa cobra una tarifa distinta a los Mandos. Es uno de los atributos historificados en el SCD2 de `dim_empleado` — si un bombero asciende, el cambio queda registrado y los hechos previos siguen atribuidos a la categoría que tenía en su momento.

{% enddocs %}


{% docs tipo_dia %}

Clasificación del día desde el punto de vista operativo del cuerpo de bomberos. Determina la **distribución de horas diurnas/nocturnas** en una guardia, no el precio por hora (eso lo determina `tipo_salario`).

| tipo_dia            | Horas diurnas | Horas nocturnas |
|---------------------|--------------:|----------------:|
| Laborable           |            15 |               9 |
| Festivo víspera     |             0 |              24 |
| Prefestivo          |             6 |              18 |
| Festivo             |             2 |              22 |
| Fin de semana       |        derivado | derivado |

**Origen del dato**:
- Cuando hay guardia operativa registrada en `stg_bronze__guards`, el `tipo_dia` viene del sistema operativo (fuente de verdad).
- Cuando no hay guardia, se aplica un fallback derivado del calendario: laborable L-V, fin de semana S-D.
- **Pendiente**: cargar el calendario oficial de festivos de Andalucía como seed para que los días sin guardia tampoco caigan en el fallback derivado.

{% enddocs %}


{% docs tipo_permiso %}

Tipos de permiso que un bombero puede solicitar. Cada tipo tiene reglas distintas de cómputo en `dias_solicitados` y de impacto en el cuadrante operativo.

| tipo_permiso                    | Descripción                                              |
|---------------------------------|----------------------------------------------------------|
| `vacaciones`                    | Vacaciones anuales reglamentarias                        |
| `asuntos propios`               | Días de asuntos propios (AP)                             |
| `horas sindicales`              | Liberación sindical contabilizada en horas               |
| `salidas personales`            | Permisos puntuales de horas dentro de una jornada        |
| `vestuario`                     | Permiso de vestuario (solicitud de prendas o equipo)     |
| `licencias por jornadas`        | Licencias contadas por jornadas completas                |
| `licencias por dias`            | Licencias contadas por días naturales                    |
| `modulo`                        | Días de módulo (permisos adicionales)                    |
| `compensacion grupos especiales`| Compensación por participación en grupos especiales      |

**Importancia analítica**: cada tipo tiene una tasa de aprobación distinta y un impacto distinto en los requerimientos forzados. El semantic model `solicitudes` permite filtrar y agregar por este atributo.

{% enddocs %}


{% docs estado_solicitud %}

Estado del ciclo de vida de una solicitud de permiso.

| Estado        | Significado                                                            |
|---------------|------------------------------------------------------------------------|
| `pendiente`   | Recién solicitada, aún no revisada por jefatura                        |
| `confirmada`  | Aprobada — el permiso es efectivo y genera asignaciones operativas     |
| `denegada`    | Rechazada por jefatura                                                 |
| `cancelada`   | Cancelada por el solicitante o el sistema antes de su confirmación     |

**Transiciones válidas**: `pendiente → confirmada / denegada / cancelada`. Una vez confirmada, una solicitud puede cancelarse (con autorización) pero esa transición es excepcional. La metric `tasa_aprobacion` se calcula como `confirmadas / total_solicitudes`.

{% enddocs %}