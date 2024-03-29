CREATE TABLE mi_tabla (
    id SERIAL PRIMARY KEY,
    datos TEXT NOT NULL
);

CREATE OR REPLACE FUNCTION fn_notificar_cambio()
RETURNS TRIGGER AS $$
BEGIN
    -- Enviar notificación con el nombre del canal 'canal_cambios' y el nuevo ID insertado como mensaje
    PERFORM pg_notify('canal_cambios', NEW.id::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_notificar_despues_insertar
AFTER INSERT ON mi_tabla
FOR EACH ROW EXECUTE FUNCTION fn_notificar_cambio();

INSERT INTO mi_tabla (datos)
VALUES ('ALEJANDRO');



-------------------------------------------------

CREATE OR REPLACE FUNCTION send_notification_push()
    RETURNS TRIGGER AS $$
DECLARE
   notification_to_send_json TEXT;
BEGIN

    notification_to_send_json := (SELECT
                                      JSONB_BUILD_OBJECT(
                                                          'notification_id', NEW.notification_id,
                                                          'notification_send_push_login',  NEW.notification_send_push_login,
                                                          'notification_message',  NEW.notification_send_push_message,
                                                          'notification_register_date',  NEW.notification_send_push_date,
                                                          'notification_register_by',  NEW.notification_send_push_register_by)
                                   );

    RAISE NOTICE '%', notification_to_send_json;
    -- Enviar notificación con el nombre del canal 'canal_cambios' y el nuevo ID insertado como mensaje
    PERFORM pg_notify('chanel_send_notification_push', CONCAT( NEW.notification_send_push_login,'*~*',NEW.notification_id,'*~*', notification_to_send_json ));

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_send_notification_push
    AFTER INSERT ON polaris_core.notifications_send_push
FOR EACH ROW EXECUTE FUNCTION send_notification_push();

CREATE OR REPLACE PROCEDURE polaris_core.get_notifications_push_client(
    in_client_login VARCHAR(255),
    OUT status BOOLEAN,
    OUT notification TEXT,
    OUT message TEXT
)
    LANGUAGE 'plpgsql'
AS
$BODY$
    --
-----------------------------------------------------------------------
--Objetivo: obtener las notificaciones push que se van a enviar al usuario
-----------------------------------------------------------------------
DECLARE
    code_error         TEXT DEFAULT ''; -- varible para almacenar codigos de errores
    message_error      TEXT DEFAULT ''; -- varible para almacenar mensajes de errores

    id_log             INTEGER; -- varible para log

    in_parameters      TEXT DEFAULT ''; -- variable para almacenar los parametros de entrada y registrarlos en log
    out_parameters     TEXT DEFAULT ''; -- variable para almacenar los parametros de salida y registrarlos en log

    success_code       VARCHAR(20) DEFAULT 'P0000'; --variabal para asignar codigo de proceso exitoso
    error_code_checked VARCHAR(20) DEFAULT 'P0001'; --variable para asignar codigo de error controlado de validaciones parametros

    --variables locales
    -----------------------------
    local_row_count    INTEGER;


BEGIN
    -- se registra inicio de transactions
    id_log := register_log_entry('API',
                                 'get_notifications_push',
                                 'NA');

    BEGIN



        --se obtienen las notificaciones de los usuarios en formato JSON
        notification := (SELECT JSONB_AGG(
                                        JSONB_BUILD_OBJECT(
                                                'notification_id', notification_id,
                                                'notification_send_push_login', notification_send_push_login,
                                                'notification_message', notification_send_push_message,
                                                'notification_register_date', notification_send_push_date,
                                                'notification_register_by', notification_send_push_register_by))
                         FROM polaris_core.notifications_send_push
                         WHERE notification_send_push_login =in_client_login
        );

        --si no se no tiene notificaciones se envia un array vacio
        IF notification IS NULL THEN
            notification := '[]';
        END IF;

        message := 'Proceso exitoso.';
        status := TRUE;

        out_parameters := 'status:' || any_element_to_string(status) || '|'
                              || 'notification:' || any_element_to_string(notification) || '|'
                              || 'message:' || any_element_to_string(message);

        PERFORM polaris_core.register_log_output(
                id_log,
                out_parameters,
                '',
                '',
                '',
                '',
                success_code,
                message);

    EXCEPTION

        WHEN SQLSTATE 'P0001' THEN
            code_error := SQLSTATE;
            message_error := SQLERRM;

            status := FALSE;
            message := SQLERRM;

            out_parameters := 'status:' || any_element_to_string(status) || '|'
                                  || 'notification:' || any_element_to_string(notification) || '|'
                                  || 'message:' || any_element_to_string(message);

            RAISE NOTICE 'Se ha producido una excepción controlada:';
            RAISE NOTICE 'Código de error: %', code_error;
            RAISE NOTICE 'Mensaje de error: %', message_error;

            -- se registra fin de transactions
            PERFORM polaris_core.register_log_output(
                    id_log,
                    out_parameters,
                    '',
                    '',
                    code_error,
                    message_error,
                    '',
                    '');

        WHEN OTHERS THEN
            code_error := SQLSTATE;
            message_error := SQLERRM;

            status := FALSE;
            message := 'Error en base de datos';

            out_parameters := 'status:' || any_element_to_string(status) || '|'
                                  || 'notification:' || any_element_to_string(notification) || '|'
                                  || 'message:' || any_element_to_string(message);

            RAISE NOTICE 'Se ha producido una excepción:';
            RAISE NOTICE 'Código de error: %', code_error;
            RAISE NOTICE 'Mensaje de error: %', message_error;

            -- se registra fin de transactions
            PERFORM polaris_core.register_log_output(
                    id_log,
                    out_parameters,
                    code_error,
                    message_error,
                    '',
                    '',
                    '',
                    '');
    END;
END ;
$BODY$;



