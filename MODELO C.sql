DROP TABLE IF EXISTS valoraciones;


CREATE TABLE Valoraciones (
	id INT PRIMARY KEY AUTO_INCREMENT,
	clienteId INT NOT NULL,
	productoId INT NOT NULL,
	puntuacion INT NOT NULL CHECK (puntuacion >= 1 AND puntuacion <=5),
	fechaValoracion DATE NOT NULL,
	FOREIGN KEY (clienteId) REFERENCES clientes(id)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	FOREIGN KEY (productoId) REFERENCES productos(id)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	UNIQUE(clienteId, productoId)
);


SELECT productos.nombre AS nombreProducto, lineaspedido.precio AS precioUnitario, lineaspedido.unidades AS unidadesCompradas
	FROM lineaspedido
	JOIN productos ON lineaspedido.productoId = productos.id
	ORDER BY lineaspedido.unidades DESC
	LIMIT 5;
	
SELECT usuarios.nombre AS nombreEmpleado, pedidos.fechaRealizacion AS fechaRealizacionPedido, SUM(lineaspedido.unidades * lineaspedido.precio) AS importeTotal, SUM(lineaspedido.unidades)
	FROM pedidos
	LEFT JOIN empleados ON pedidos.empleadoId = empleados.id
	LEFT JOIN usuarios ON empleados.usuarioId = usuarios.id
	WHERE DATEDIFF(CURDATE(), pedidos.fechaRealizacion) > 7
	GROUP BY pedidos.id, usuarios.nombre, pedidos.fechaRealizacion;
	
	
DELIMITER //

CREATE PROCEDURE bonificarPedido(
	IN v_pedidoId INT
)

	BEGIN
		
		DECLARE EXIT FOR SQLEXCEPTION 
			BEGIN
				ROLLBACK;
			END;
			
		DECLARE empleadoPedido INT;
		DECLARE nuevoEmpleado INT;
		
		START TRANSACTION;
		
		SELECT pedidos.empleadoId INTO empleadoPedido FROM pedidos WHERE pedidos.id = p_pedidoId;
		
		IF empleadoId IS NULL THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El pedido no tiene gestor'
		END IF;
		
		SELECT pedidos.empleadoId INTO nuevoEmpleado FROM pedidos WHERE pedidos.empleadoId <> empleadoPedido LIMIT 1;
		
		UPDATE pedidos SET pedidos.empleadoId = nuevoEmpleado WHERE pedidos.id = v_pedidoId;
		
		COMMIT;
		
	END //

DELIMITER ;


DELIMITER //

CREATE TRIGGER p_limitar_unidades_mensuales_de_productos_fisicos
BEFORE INSERT ON LineasPedido
FOR EACH ROW
BEGIN
    DECLARE v_es_fisico INT DEFAULT 0;
    DECLARE v_unidades_mes INT DEFAULT 0;

    -- 1. Comprobar si el producto que se añade es de tipo 'Físico'
    SELECT COUNT(*) 
    INTO v_es_fisico
    FROM Productos p
    JOIN TiposProducto tp ON p.tipoProductoId = tp.id
    WHERE p.id = NEW.productoId 
      AND (tp.nombre = 'Físico' OR tp.nombre = 'Fisico');

    -- 2. Si es físico, calcular el acumulado vendido en el mes en curso
    IF v_es_fisico > 0 THEN
        SELECT IFNULL(SUM(lp.unidades), 0)
        INTO v_unidades_mes
        FROM LineasPedido lp
        JOIN Pedidos p ON lp.pedidoId = p.id
        WHERE lp.productoId = NEW.productoId
          AND YEAR(p.fechaRealizacion) = YEAR(CURDATE())
          AND MONTH(p.fechaRealizacion) = MONTH(CURDATE());

        -- 3. Abortar si la suma acumulada más la nueva compra supera las 1000 unidades
        IF (v_unidades_mes + NEW.unidades) > 1000 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Operación cancelada: Se supera el límite mensual de 1000 unidades para este producto físico.';
        END IF;
    END IF;
END //

DELIMITER ;
	
		
			