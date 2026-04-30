WITH 

-- import CTE
src_vehicles AS (
    SELECT *
    FROM {{ source('bronze', 'vehicles') }}
),

-- renombrado
vehicles_renamed AS (
    SELECT
        MATRICULA AS matricula_token
        , TRIM(NOMBRE) AS nombre_vehiculo
        , ID_PARQUE AS id_parque
        , {{ limpiar_texto('TIPO') }} AS tipo_vehiculo
        , ANO AS anio_vehiculo
        {{ campos_auditoria() }}
    FROM src_vehicles
)

SELECT * FROM vehicles_renamed