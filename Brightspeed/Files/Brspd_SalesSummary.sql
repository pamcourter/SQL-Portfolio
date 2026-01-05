/****** Object:  StoredProcedure [dbo].[rs_Brightspeed_OB_ListSalesSummary_MRR]    Script Date: 1/5/2026 12:47:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Pam
-- Create date: 7/11/25
-- Description: Display MRR data for sales 
-- EXEC 
-- =============================================
CREATE PROCEDURE [dbo].[rs_Brightspeed_OB_ListSalesSummary_MRR]
	-- Add the parameters for the stored procedure here
	@StartDate_p DATETIME,
	@EndDate_p DATETIME	

AS

BEGIN
	
	SET NOCOUNT ON;

	DECLARE @StartDate DATETIME = @StartDate_P --'8/4/25'
	DECLARE @EndDate DATETIME = @EndDate_p --getdate()

;

	SELECT 
	
		LeadListname as ListName 	
		, TotalRev = sum(discountprice) 
		, totSales = sum(case when revenue > 0 then 1 else 0 end)		
		,VoiceSeats = sum( case when Group2 = 'Voice+' then 1
								when group1 = 'BBF COMPLETE SUITE PKG' then 2 else 0 end)
		,BBF = sum(case when group2='BBF'  then 1 else  0 end)
		,P_BBF = sum(case when group2 = 'P-BBF' then 1 else 0 end)
		,StaticIP = sum(case when group2='Static IP'  then cast(group3 as int) else  0 end)	
								--when group1 = 'BBF COMPLETE SUITE PKG' then 5 else  0 end)		
		,misc=sum(case when group2='Miscellaneous'  then 1 else  0 end)		
		, Pots = sum(case when group2 = 'POTS' then 1 else 0 end)	
		,BBFRev = sum(case when group2='BBF'  then discountprice else 0 end)
		,StaticIPRev =  sum(case when group2='Static IP'  then  discountprice *cast(group3 as int) else 0 end)
		,P_BBFRev =sum(case when group2 = 'P-BBF'   then discountprice else 0 end)		
		,VoiceSeatsRev = sum(case when Group2 = 'Voice+'  then discountprice else 0 end)
		,MiscRev = sum(case when group2='Miscellaneous'    then discountprice else 0 end)
		, PotsRev = sum(case when group2 = 'POTS' then discountprice else 0 end)
	

	FROM 
	(select l.*,p.productname, discountprice, group1, group2, group3, revenue,
			r = rank() OVER (PARTITION BY i.LeadID ORDER BY i.[CreatedAt] aSC)	
	from 
		(	select * from brightspeed.dbo.interactions i(nolock)  
			where CreatedAt between @StartDate and dateadd (day, 1, @EndDate)
		
		)i
		left join Brightspeed.dbo.Leads_CRM l (nolock)
			on l.leadid = i.leadid
		left join (
				select *
				from incontact_userhub.dbo.cdrplus cdr (nolock) 
				where campaign_name like '%bright%speed%' and start_date between @StartDate and dateadd (day, 1, @EndDate)
			)cdr on i.ContactID = cdr.contact_ID
		LEFT OUTER JOIN Brightspeed..Dispositions dd ON i.DispositionID = dd.DispositionID
		LEFT OUTER JOIN inContact_UserHub..Agents a (Nolock) ON l.InContactAgentID=a.agent_no
		full join brightspeed.dbo.orders o on l.leadid = o.leadid
		left join brightspeed.dbo.products p on o.productid = p.productID

	where (dd.issale = 1 or (o.leadid is not null and o.active = 1 and dd.issale is null))
		and leadlistname not like '%testing%'
		and i.createdat between @startdate and dateadd(day, 1, @enddate)
	) ds where r = 1

	group by leadListName 

option (recompile)
END

GO
