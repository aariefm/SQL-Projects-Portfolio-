WITH 
production_receipt 
AS(
SELECT 
	T11.DocNum							AS ProdRecepitNo,
	CONVERT(varchar,T11.DocDate, 23)	AS POCloseDate,
	T7.CardName							AS CustomerName,									
	T8.Project							AS SalesOrderNo,
	T7.U_REF10							AS QuoteNo,
	T7.NumAtCard						AS PurchaseOrderNo,
	T1.ItemCode							AS part_num,								
	T1.Comments							AS part_description,
	--T4.ItemName							AS part_description,
	CAST(T8.Quantity AS INT)			AS qty,
	--CASE 
	--WHEN (T14.DocStatus='C' /*OR T14a.DocStatus='C'*/) THEN 'Shipped'						
	--ELSE 'To be shipped' END AS SAP_ship_status,
	T7.U_OS AS SAP_ship_status,
	--COALESCE(CAST(T14.DocNum AS nchar), '-'/*,CAST(T14a.DocNum AS nchar)*/)	AS DLN_num,
	--COALESCE(T14.Comments,'-')/*,T14a.Comments)*/					AS INVOICEorDLNremarks,
	T4.ItmsGrpCod						AS item_group,
	'1'									AS row_type
		
	FROM IGN1 T8 
		LEFT JOIN OIGN T11 ON T8.DocEntry = T11.DocEntry
		LEFT JOIN OWOR T1 ON T8.BaseRef = T1.DocNum
		LEFT JOIN ORDR T7 ON  T1.OriginNum = T7.DocNum
		INNER JOIN OITM T4 ON T1.ItemCode = T4.ItemCode 
		--INNER JOIN ODLN T14 ON T7.NumAtCard = T14.NumAtCard 
		--INNER JOIN ODLN T14a ON T7.U_REF10=T14a.U_REF10
		--LEFT JOIN ODLN T14 ON T14.ImportEnt = T7.DocNum AND T7.U_REF10 = T14.U_REF10
		--LEFT JOIN ODLN T14 ON Replace(T14.NumAtCard, ' ', '') = Replace(T7.NumAtCard, ' ', '') OR T7.U_REF10 = T14.U_REF10
		--LEFT JOIN ODLN T14a ON Right(T14a.Comments,6) LIKE concat('%',T8.Project,'%')

	WHERE	--YEAR(T11.DocDate) = 2025  	--'4' is Last 3 years, '1' is current year	
			YEAR(T11.DocDate) = YEAR(GETDATE())		-- Only include products built in the CURRENT year.
			AND (T4.ItmsGrpCod = 143			-- Item group codes for pump 
			OR T4.ItmsGrpCod = 190)			-- Skid assm
			AND T11.Comments IS NULL				-- THIS IS ADDED TO ENSURE ANY REBUILD/CORRECTIONS/MISTAKES ARE NOT COUNTED!
			AND (T1.Type != 'D' OR T1.Status != 'C' 
			OR T1.Comments NOT LIKE '%replaces%'
			OR T11.Comments NOT LIKE '%wrong%')
)
,
summaryrows		-- CTE for Summation Rows that will be unioned 
AS (
	SELECT 
	'-'					AS POCloseDate_yyyymmdd,					-- 1.
	'-'					as ProdReceiptNo,
	'-'					AS CustomerName,							-- 2.
	'-'					AS SalesOrderNo,							-- 3.
	'-'					AS QuoteNo,
	'-'					AS PurchaseOrderNo,
	'-'					AS part_num,								-- 4.
	CONCAT(year(POCloseDate), ' ',
	CASE 
		WHEN item_group = 143 THEN 'Pumps Built' 
		WHEN item_group = 190 THEN 'Skids Assembled' END,
	' total ')		AS part_description,							-- 5.
	SUM(qty)		AS qty,											-- 6.
	SAP_ship_status		AS SAP_ship_status,
	--'-'	AS DLN_num,									-- 7.
	--'-'AS remarks,									-- 8.
	item_group		AS item_group,								
	'2'				AS row_type									

	FROM production_receiptsn
	
	GROUP BY item_group, SAP_ship_status, year(POCloseDate)--,part_num
) 

SELECT * FROM production_receipt
UNION ALL
SELECT *  FROM summaryrows

order by row_type DESC, SAP_ship_status DESC, SalesOrderNo desc, POCloseDate desc, part_description desc, item_group, ProdRecepitNo DESC 