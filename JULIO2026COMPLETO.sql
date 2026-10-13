SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS recepciones;
DROP TABLE IF EXISTS lineasrecepcion;



CREATE TABLE Recepciones(
	id INT PRIMARY KEY AUTO_INCREMENT,
	fechaRecepcion DATE NOT NULL,
	pedidoId INT NOT NULL,
	comentarios TEXT,
	FOREIGN KEY (pedidoId) REFERENCES pedidos(id)
		ON DELETE CASCADE
		ON UPDATE CASCADE
	
);

CREATE TABLE Lineasrecepcion(
	id INT PRIMARY KEY AUTO_INCREMENT,
	lineapedidoId INT NOT NULL,
	cantidad INT NOT NULL,
	recepcionId INT NOT NULL,
	CONSTRAINT chk_cantidad_recepcion_positiva CHECK (cantidad > 0),
	FOREIGN KEY (lineapedidoId) REFERENCES lineaspedido(id)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	FOREIGN KEY (recepcionId) REFERENCES recepciones(id)
		ON DELETE CASCADE
		ON UPDATE CASCADE
);



SELECT usuarios.nombre AS nombreCliente, pedidos.id AS pedidoId, pedidos.fechaRealizacion AS fechaPedido 
	FROM pedidos
	JOIN clientes ON pedidos.clienteId = clientes.id
	JOIN usuarios ON clientes.usuarioId = usuarios.id
	JOIN recepciones ON pedidos.id = recepciones.pedidoId
	GROUP BY pedidos.id, usuarios.nombre, pedidos.fechaRealizacion
	HAVING DATEDIFF(MIN(recepciones.fechaRecepcion), pedidos.fechaRealizacion) > 7;	
	
	
	
SELECT usuarios.nombre AS nombreCliente, clientes.id AS clienteId, SUM(lineaspedido.unidades * lineaspedido.precio) AS totalPedidoSinRecepcionar
	FROM clientes 
	JOIN usuarios ON clientes.usuarioId = usuarios.id
	JOIN pedidos ON clientes.id = pedidos.clienteId
	JOIN lineaspedido ON pedidos.id = lineaspedido.pedidoId
	LEFT JOIN recepciones ON recepciones.pedidoId = recepciones.pedidoId
	WHERE recepciones.id IS NULL
	GROUP BY clientes.id, usuarios.nombre
	HAVING totalPedidoSinRecpecionar > 500;

DELIMITER //	
	
CREATE OR REPLACE PROCEDURE RecepcionarPedidoCompleto(
	IN p_pedidoId INT	
)

BEGIN
	DECLARE v_num_fisicos INT;
	DECLARE v_recepcion_id INT;
	
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Error";
	END;
	
	START TRANSACTION;
	
	
    SELECT COUNT(*)
    INTO v_num_fisicos
    FROM LineasPedido lp
    JOIN Productos pr ON lp.productoId = pr.id
    JOIN TiposProducto tp ON pr.tipoProductoId = tp.id
    WHERE lp.pedidoId = p_pedido_id
      AND (tp.nombre = 'Fisico' OR tp.nombre = 'Físico');

	IF v_num_fisicos = 0 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se permite recepcionar pedidos de productos digitales.';
   END IF;
   
   
   INSERT INTO Recepciones (pedidoId, fechaRecepcion, comentarios)
    VALUES (p_pedidoId, NOW(), 'Recepción completa creada automáticamente');
    
    SET v_recepcion_id = LAST_INSERT_ID();
    
   INSERT  INTO lineasrecepcion(lineapedidoId, cantidad, recepcionId) SELECT lineaspedido.id, lineaspedido.unidades, v_recepcion_id FROM lineaspedido 
   	JOIN productos ON lineaspedido.productoId = productos.id
   	JOIN tiposproducto ON tiposproducto.id = productos.tipoProductoId
   	WHERE lineaspedido.pedidoId = p_pedidoId AND tiposproducto.nombre = 'Físico';
   	
   COMMIT;
   
END //

DELIMITER ;


DELIMITER //

CREATE TRIGGER asegurar_recepcion_correcta BEFORE INSERT ON lineasrecepcion FOR EACH ROW

	BEGIN
	
		DECLARE tipoProducto INT;
		DECLARE unidades INT;
		DECLARE v_unidades_ya_recepcionadas INT;
		
		
		SELECT tiposproducto.nombre, lineaspedido.unidades INTO tipoProducto, unidades FROM lineaspedido 
			JOIN productos ON lineaspedido.productoId = productos.id
			JOIN tiposproducto ON tiposproducto.id = productos.tipoProductoId
			WHERE lineaspedido.id = NEW.lineaPedidoId;
			
			
		IF tipoProducto = 'Digital' THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se pueden recepcionar productos digitales';
		END IF;
		
		
		SELECT COALESCE(SUM(cantidad), 0) INTO v_unidades_ya_recepcionadas FROM lineasrecepcion WHERE lineaPedidoId = NEW.lineaPedidoId;
		
		IF (v_unidades_ya_recepcionadas + NEW.cantidad) > unidades THEN
			SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT 'Error: No se pueden recepcionar más unidades de las pedidas.';
		END IF;
		
END //
	
DELIMITER ;
		
		





