const pool = require("../db");

async function createUser(req, res){
    const {first_name, last_name, email, password, birthDate, country_id, gender, native_lang_id, target_lang_id, description} = req.body;
    try {
        const result = await pool.query(
            "SELECT FUNCTION fun_insert_usuarios($1, $2, $3, $4)", [first_name, last_name, email, password, birthDate, country_id, gender, native_lang_id, target_lang_id, description]
        );
    } catch (error) {
        res.status(500).json({ error: "Error insertando usuario" });
    }
}