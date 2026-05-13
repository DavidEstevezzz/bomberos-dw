WITH 

-- import CTE
src_vehicles AS (
    SELECT *
    FROM {{ source('bronze', 'vehicles') }}
),

-- renombrado, limpieza y tipado
vehicles_renamed AS (
    SELECT
        NULLIF(TRIM(MATRICULA), '') AS matricula_token
        , NULLIF(TRIM(NOMBRE), '') AS nombre_vehiculo
        , TRY_TO_NUMBER(ID_PARQUE)::NUMBER(38,0) AS id_parque
        , {{ limpiar_texto('TIPO') }} AS tipo_vehiculo
        , TRY_TO_NUMBER(ANO)::NUMBER(38,0) AS anio_vehiculo
        {{ campos_auditoria() }}
    FROM src_vehicles
)

SELECT * FROM vehicles_renamed