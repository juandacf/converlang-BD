CREATE OR REPLACE FUNCTION fun_get_messages_by_match(p_match_id INTEGER)
RETURNS TABLE (
    message_id INTEGER,
    sender_id INTEGER,
    message TEXT,
    sent_at TIMESTAMP,
    is_corrected BOOLEAN,
    is_read BOOLEAN
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cl.message_id,
        cl.sender_id,
        cl.message,
        cl.timestamp AS sent_at,
        cl.is_corrected,
        cl.is_read
    FROM chat_logs cl
    WHERE cl.match_id = p_match_id
    ORDER BY cl.timestamp ASC;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fun_send_message(
    p_match_id INTEGER,
    p_sender_id INTEGER,
    p_message TEXT
)
RETURNS TABLE (
    message_id INTEGER,
    sender_id INTEGER,
    message TEXT,
    sent_at TIMESTAMP,
    is_read BOOLEAN
)
AS $$
BEGIN
    RETURN QUERY
    INSERT INTO chat_logs (match_id, sender_id, message)
    VALUES (p_match_id, p_sender_id, p_message)
    RETURNING 
        chat_logs.message_id,
        chat_logs.sender_id,
        chat_logs.message,
        chat_logs.timestamp AS sent_at,
        chat_logs.is_read;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fun_get_chat_list(p_user_id INTEGER)
RETURNS TABLE (
    match_id INTEGER,
    other_user_id INTEGER,
    full_name TEXT,
    last_message TEXT,
    last_message_time TIMESTAMP
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.match_id,
        CASE 
            WHEN m.user_1 = p_user_id THEN m.user_2
            ELSE m.user_1
        END AS other_user_id,
        CONCAT(u.first_name, ' ', u.last_name) AS full_name,
        (
            SELECT cl.message
            FROM chat_logs cl
            WHERE cl.match_id = m.match_id
            ORDER BY cl.timestamp DESC
            LIMIT 1
        ) AS last_message,
        (
            SELECT cl.timestamp
            FROM chat_logs cl
            WHERE cl.match_id = m.match_id
            ORDER BY cl.timestamp DESC
            LIMIT 1
        ) AS last_message_time
    FROM user_matches m
    JOIN users u 
      ON u.id_user = CASE 
                        WHEN m.user_1 = p_user_id THEN m.user_2
                        ELSE m.user_1
                     END
    WHERE m.user_1 = p_user_id
       OR m.user_2 = p_user_id
    ORDER BY last_message_time DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;


