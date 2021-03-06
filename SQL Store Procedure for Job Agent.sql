USE [Company_Reports]
GO
/****** Object:  StoredProcedure [dbo].[sp_Orders_ Created]   Script Date: 2/22/2022 10:05:35 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Create Procedure [dbo].[sp_Orders_ Created]


as
Begin 


Declare @v_Count int,@v_OpenEvents VARCHAR(500)


select @v_Count = Count(*)

from (
select Order.AddressCode as Site, Order.OrderNumber,  Order.Status, Order.userdate1 as STAB, soo.TranNo,
Order.usertext8 as whsestatus, Order.usertext9 as configstatus,
cast(dbo.fn_Order.OrderShipDate_BW(Order.OrderNumber) as date) as ShipDate, 
Order.UserText1 as priority, Order.ShippingMethod, Order.TransferNumber as Ref, pt.projectnumber, Order.EnteredByUser,Order.usertext2 as Order.tatus, Order.CreateDate
from Ordertable Order.
join occasion occ on occ.incidentnumber = Order.incidentnumber
join projecttask pt on pt.id = occ.projecttaskid
join SalesOrderTTS so on so.Order.ey = Order.Order.isitionNumber
join SalesOrder soo on soo.SOKey = so.SOKey
where  
Order.CreateDate >= DATEADD(Hour, -2, GETDATE()) and
Order.usertext2 = 'Stock' and pt.projectnumber ='123' 
and Order.createdate > '2022-01-28'
--and  Order.CreateDate IN (Select Value From dbo.fn_GetTotalWorkingDaysUsingLoop (@CreateDate,','))
) wrap
group by site, Order.OrderNumber, status, stab, shipdate, priority, ShippingMethod, ref, projectnumber, whsestatus, configstatus, EnteredByUser, createdate, TranNo, Order.tatus
order by stab

if @v_Count > 0

BEGIN

declare @email_body varchar(500) = 'Events with Errors: ' + '<br />' + @v_OpenEvents



EXEC msdb.dbo.sp_send_dbmail
@profile_name='DBMail Profile',
@recipients= 'someonesgmail.com',
@subject='There are orders created in the last 2 hours',
@body= @email_body ,
@body_format = 'HTML',
@importance= 'HIGH';



END



END






 
