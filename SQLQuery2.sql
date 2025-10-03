create database Normalizada
use Normalizada

--borrar tablas solop si existen
IF OBJECT_ID('dbo.StagingVentas','U') IS NOT NULL DROP TABLE dbo.StagingVentas;
IF OBJECT_ID('dbo.CleanVentas','U') IS NOT NULL DROP TABLE dbo.CleanVentas;
IF OBJECT_ID('dbo.Productos','U')  IS NOT NULL DROP TABLE dbo.Productos;
IF OBJECT_ID('dbo.Clientes','U') IS NOT NULL DROP TABLE dbo.Clientes;
IF OBJECT_ID('dbo.Ventas','U') IS NOT NULL DROP TABLE dbo.Ventas;

---- 2 tabla temporal staging TODO EN VARCHAR para evitar errores al importar

CREATE TABLE dbo.StagingVentas(
	RawID_Venta VARCHAR(50),
	RawFecha VARCHAR(100),
	RawProducto VARCHAR(100),
	RawPrecio VARCHAR(100),
	RawCantidad VARCHAR(100),
	RawTotal VARCHAR(100),
	RawCliente VARCHAR(100),
	RawPais VARCHAR(100)--
);



-- INSERTAR ESTE CSV DENTRO DE MI TABLA
BULK INSERT dbo.StagingVentas
FROM 'E:\ventas_200.csv'
with
(
	FIRSTROW=2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR ='0x0a',-- cambio corregido//
	codepage='65001', -- UTF-8
	TABLOCK
);

select count (*) as FilasStaging from dbo.StagingVentas;
select top(10) * from dbo.StagingVentas;
select* from dbo.StagingVentas

CREATE TABLE Productos (
	ID_Producto INT PRIMARY KEY IDENTITY(1,1),
	Nombre_Producto VARCHAR(100) NOT NULL,
	------ esta fila de abajo se usa para asegurar que no tengamos productos co el mismo nombre
	CONSTRAINT UQ_Nombre_Producto UNIQUE (Nombre_Producto)
);
GO
Create TABLE Clientes(
	ID_Cliente int primary key identity(1,1),
	Nombre_Cliente VARCHAR(100) NOT NULL,
	Pais VARCHAR(100) NOT NULL,
	CONSTRAINT UQ_Nombre_Cliente UNIQUE(Nombre_Cliente)
);
GO ---------------------------------------------------------
create table Ventas(
	ID_Venta INT PRIMARY KEY,
	Fecha DATE NOT NULL,
	Precio_Unitario Decimal (10,2) not null,
	Cantidad INT NOT NULL,
	Total_Venta Decimal(10,2) NOT NULL,
	ID_Producto INT NOT NULL,
	ID_Cliente INT NOT NULL,
	CONSTRAINT FK_Ventas_Productos FOREIGN KEY(ID_Producto) References Productos(ID_Producto),
	CONSTRAINT FK_Ventas_Clientes FOREIGN KEY(ID_Cliente) references Clientes(ID_Cliente)
);


print 'Poblando la tabla de productos';
INSERT INTO Productos(Nombre_Producto)
SELECT
	DISTINCT
	RawProducto
from
	dbo.StagingVentas
where
	RawProducto IS NOT NULL AND RawProducto !='';

--Print
print 'poblando la tabla de clientes'
INSERT INTO Clientes(Nombre_Cliente,Pais)
SELECT
	DISTINCT
	RawCliente,
	RawPais
FROM
	dbo.StagingVentas
where
	RawCliente is not null and RawCliente !='';

select * from dbo.Productos

DROP TABLE Ventas
DROP TABLE Clientes

CREATE TABLE Paises(
	ID_Pais int primary key identity(1,1),
	Nombre_Pais VARCHAR(100) NOT NULL,
	CONSTRAINT UQ_Nombre_Pais UNIQUE (Nombre_Pais)

);


--- tabla clientes actualizada
CREATE TABLE Clientes (
	ID_Cliente int primary key identity(1,1),
	Nombre_Cliente VARCHAR(100) NOT NULL,
	ID_Pais int not null,
	CONSTRAINT UQ_Nombre_Cliente UNIQUE(Nombre_Cliente),
	CONSTRAINT FK_Clientes_Paises FOREIGN KEY (ID_Pais) references Paises(ID_Pais) 
);


inserT INTO Paises(Nombre_Pais)
select
	DISTINCT
	RawPais
FROM 
	StagingVentas
WHERE
	RawPais is not null and RawPais !='';

select * from Productos
select * from Paises

PRINT 'Poblando la tabla de clientes'
--1 agrupamos los datos de nuestra tabla staging para asignar un solo pais a cada cliente
--2 se une la informacion con la tabla pais para sacar su  ID
WITH ClientePaisUnico as (
	SELECT
		RawCliente,
		MAX(RawPais) as PaisAsignado
	from StagingVentas
	where RawCliente is not null and RawCliente !=''
	group by RawCliente
)
INSERT INTO Clientes(Nombre_Cliente,ID_Pais)
SELECT
	cpu.RawCliente,
	p.ID_Pais
from
	ClientePaisUnico cpu
join
	Paises p on cpu.PaisAsignado = p.Nombre_Pais;

select * from Clientes


PRINT 'POBLANDO LA TABLA VENTAS'

INSERT INTO Ventas(ID_Venta,Fecha, Precio_Unitario, Cantidad, Total_Venta, ID_Producto, ID_Cliente)
SELECT
	s.RawID_Venta,
	TRY_CONVERT(DATE,s.RawFecha),
	TRY_CONVERT(DECIMAL(10,2),s.RawPrecio),
	TRY_CONVERT(int, s.RawCantidad),
	TRY_CONVERT(decimal(10,2),s.RawTotal),
	p.ID_Producto,
	c.ID_Cliente
from StagingVentas s
join Productos p on  s.RawProducto = p.Nombre_Producto
join Clientes c on s.RawCliente = c.Nombre_Cliente
where
	TRY_CONVERT(DATE, s.RawFecha) is not null
	and TRY_CONVERT(int, s.RawCantidad) is not null
	and TRY_CONVERT(decimal(10,2), s.RawTotal) is not null
	and TRY_CONVERT(decimal(10,2), s.RawPrecio) is not null;
go

SELECT
	SUM(Total_Venta) AS Ingresos_Totales,
	sum(Cantidad) as Unidades_Vendidas
FROM
	Ventas; 