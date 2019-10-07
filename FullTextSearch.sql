USE [PRP]
GO

/****** Object:  StoredProcedure [dbo].[qryInPRPWebSearch]    Script Date: 10/07/2019 10:12:10 ******/
SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER OFF
GO





CREATE PROCEDURE [dbo].[qryInPRPWebSearch] 

@search varchar(100),
@prl varchar(4) = NULL

AS

Set NOCOUNT ON

declare @strSearch varchar(100)
declare @numSearch varchar(24)

set @strSearch = '"' + @search + '"' -- needed for contains and fulltext search types
set @numSearch = dbo.ConvertToNumeric(@search)

-- alias table joined to tblInItem
select 'A' as Type, i.itemid, a.AliasID, ISNULL(a.AliasID,i.ItemId) as PartNumber, -- Alias table search
i.Descr + ' ' + CAST(CASE WHEN d.AddlDescr IS NULL THEN '' ELSE d.AddlDescr END AS varchar(255)) AS ItemDescr, 
ISNULL(a.ProductLine, i.ProductLine) AS MfrProductLine, CAST('' as varchar) as [KEY], CAST(900 as int) as [RANK] into #TempSrchHits 
FROM dbo.tblInItemAlias a INNER JOIN dbo.tblInItem i ON a.ItemID = i.ItemId 
LEFT OUTER JOIN dbo.tblInItemAddlDescr d ON i.ItemId = d.ItemId 
where (i.numericid = @search or CONTAINS(i.descr, @strSearch) or a.numericid = @search 
or i.itemid = @search or a.aliasid = @search) 
and a.AlternateYn = 0 -- MJM/PRP 4/21/16
--AND i.productline = @Class --or a.Productline = @Class
Union
 -- tblInItem only
Select 'I' as Type, i.itemid, '', i.itemid as PartNumber, 
i.Descr + ' ' + CAST(CASE WHEN d.AddlDescr IS NULL THEN '' ELSE d.AddlDescr END AS varchar(255)) AS ItemDescr, 
i.productline as MfrProductLine, CAST('' as varchar) as [KEY], CAST(1000 as int) as [RANK] 
from tblInItem i LEFT outer join tblInItemAddlDescr d on i.itemid = d.itemid 
where (i.numericid = @search) or (CONTAINS(i.descr, @strSearch) 
or (i.itemid = @search))
union
-- partial numeric match
select 'P' as Type, i.itemid, a.AliasID, ISNULL(a.AliasID,i.ItemId) as PartNumber,
i.Descr + ' ' + CAST(CASE WHEN d.AddlDescr IS NULL THEN '' ELSE d.AddlDescr END AS varchar(255)) AS ItemDescr, 
ISNULL(a.ProductLine, i.ProductLine) AS MfrProductLine, CAST('' as varchar) as [KEY], CAST(700 as int) as [RANK]
FROM dbo.tblInItemAlias a INNER JOIN dbo.tblInItem i ON a.ItemID = i.ItemId 
LEFT OUTER JOIN dbo.tblInItemAddlDescr d ON i.ItemId = d.ItemId 
where (i.numericid like '%' + @search + '%' or CONTAINS(i.descr, @strSearch) or a.numericid like '%' + @search + '%'
or i.itemid = @search or a.aliasid = @search) 
and a.AlternateYn = 0
union
-- fix for 0 prefix numeric searches (see AB DICK 9800 numbers)
SELECT '0' as Type ,i.itemid, a.AliasID, ISNULL(a.AliasID,i.ItemId) as PartNumber, -- dropped zero numeric search
i.Descr + ' ' + CAST(CASE WHEN d.AddlDescr IS NULL THEN '' ELSE d.AddlDescr END AS varchar(255)) AS ItemDescr, 
ISNULL(a.ProductLine, i.ProductLine) AS MfrProductLine, CAST('' as varchar) as [KEY], CAST(600 as int) as [RANK] 
FROM dbo.tblInItemAlias a INNER JOIN dbo.tblInItem i ON a.ItemID = i.ItemId 
LEFT OUTER JOIN dbo.tblInItemAddlDescr d ON i.ItemId = d.ItemId 
where (i.numericid = CASE WHEN CHARINDEX('0', @search, 1) = 1 THEN 
CAST(CAST(@search AS INTEGER) AS VARCHAR) 
ELSE 
@search 
END or CONTAINS(i.descr, @strSearch) or a.numericid = CASE WHEN CHARINDEX('0', @search, 1) = 1 THEN 
CAST(CAST(@search AS INTEGER) AS VARCHAR) 
ELSE
@search 
END 
or i.itemid = @search or a.aliasid = @search) and a.AlternateYn = 0 -- MJM/PRP 4/21/16
union
SELECT 'N' as Type, i.itemid, a.AliasID, ISNULL(a.AliasID,i.ItemId) as PartNumber, -- pure numeric search
i.Descr + ' ' + CAST(CASE WHEN d.AddlDescr IS NULL THEN '' ELSE d.AddlDescr END AS varchar(255)) AS ItemDescr, 
ISNULL(a.ProductLine, i.ProductLine) AS MfrProductLine, CAST('' as varchar) as [KEY], CAST(800 as int) as [RANK] 
FROM dbo.tblInItem i left join tblInItemAlias a on i.itemid = a.itemid 
LEFT JOIN dbo.tblInItemAddlDescr d ON i.ItemId = d.ItemId 
where i.numericid = @numSearch and i.numericid <> '' 
or a.numericid = @numSearch and a.numericid <> '' and a.AlternateYn = 0 -- MJM/PRP 4/21/16
union
SELECT 'F' as Type, i.itemid, a.AliasID, ISNULL(a.AliasID,i.ItemId) as PartNumber, -- full text enhancement
i.Descr + ' ' + CAST(CASE WHEN d.AddlDescr IS NULL THEN '' ELSE d.AddlDescr END AS varchar(255)) AS ItemDescr, 
ISNULL(a.ProductLine, i.ProductLine) AS MfrProductLine, KEY_TBL.* 
FROM dbo.tblInItem i left join tblInItemAlias a on i.itemid = a.itemid 
LEFT JOIN dbo.tblInItemAddlDescr d ON i.ItemId = d.ItemId 
INNER JOIN 
FREETEXTTABLE(tblInItem, Descr, @Search) AS KEY_TBL 
ON i.itemid = KEY_TBL.[KEY] 
where a.AlternateYn = 0 -- MJM/PRP 4/21/16
Union
-- Description 
Select 'D' as Type, i.itemid, a.AliasID, ISNULL(a.AliasID,i.ItemId) as PartNumber,  
i.Descr + ' ' + CAST(CASE WHEN d.AddlDescr IS NULL THEN '' ELSE d.AddlDescr END AS varchar(255)) AS ItemDescr, 
ISNULL(a.ProductLine, i.ProductLine) AS MfrProductLine, CAST('' as varchar) as [KEY], CAST(700 as int) as [RANK]  
from tblInItem i inner JOIN dbo.tblInItemAlias a ON 
i.ItemID = a.ItemId left JOIN dbo.tblInItemAddlDescr d  
ON i.ItemId = d.ItemId 
where i.descr like '%' + @Search + '%'
or freetext(descr, @Search) and a.AlternateYn = 0 -- MJM/PRP 4/21/16
--AND i.productline = @Class or a.Productline = @Class


if @prl IS NOT NULL
BEGIN
select DISTINCT * from #TempSrchHits 
where MfrProductLine = @prl
order by [RANK] desc
END
ELSE
BEGIN
select DISTINCT * from #TempSrchHits 
order by [RANK] desc
END

GO

