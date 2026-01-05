/****** Object:  StoredProcedure [dbo].[rs_Brightspeed_OB_Sales_Details]    Script Date: 1/5/2026 12:47:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Pam
-- Create date: 7/11/25
-- Description:
-- EXEC 
-- =============================================
CREATE PROCEDURE [dbo].[rs_Brightspeed_OB_Sales_Details]
	-- Add the parameters for the stored procedure here
	@StartDate_p DATETIME,
	@EndDate_p DATETIME
	

AS

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering WITH SELECT statements.
	SET NOCOUNT ON;

DECLARE @StartDate DATETIME --= '7/10/25'
DECLARE @EndDate DATETIME --= '7/11/25'
 declare  @TimeZoneadj int = 1 --cst


SET @StartDate = @StartDate_p
SET @EndDate = @EndDate_p
	
;


SELECT LeadListName,
	LeadID,
	convert(varchar, createdat, 101) as CallDate, 	 
	AccountPhone = [Account Phone Number]
	,contact_ID	
	, Callback = DateAdd(HOUR,1,CallbackDateMST)
	, ContactName = [Contact First Name] + ' ' +  [Contact Last Name]
	, Interactions
	, Timezone
	, Comments = [Comments Log]
	, Gatekeeper = [Gatekeeper Name]
	, Disposition = DispositionName
	, InContactAgentID
	, AgentName=First_Name +' ' +Last_Name
	,employee_internal_id = internalid
	, start_date as LastCallDate
	, CalledPhone 
	, calltimestamp = dateadd(hour, @TimeZoneadj,start_date)		
	, agent_time
	, acw_time	
	, class	
	, [Account#],	[Location Account Name],	[AccountOwner],	[Street Address]	
	, [Address Sub],	City,	State,	[Zip Code],	County, [Metro/Micro],	[MSAName]
	, [NAICS_Code],	[SmartBiz Enabled],	[Qualified Date],	[AMS ID],	[Record ID]	
	, [Industry],	[Contact First Name],	[Contact Last Name],	[Contact Type]
	, [Contact Email],	[Contact Phone],	[Current Fiber Provider], [Current Speed]
	, [Current Price],	[Current Contract Status],	[Curent Voice Solution],[GooglePlaces]	
	, AltPhone1,	AltPhone2,	AltPhone3,	GooglePhone,GoogleWebsite,	[Gatekeeper Name]		
	,attemptrank --at what attempt did the sale occur
	,agreementClosed= case when agreementClosed = 1 then 'Closed - Win'
	                      when agreementClosed = 2 then 'Closed - Lost' 
						  else 'Pending' end 
	, ClosedDate, [Opportunity #], [Lead Status], [Lead Status Reason]
	, Acting_AgentID,productname, DiscountPrice,revenue,  productid

FROM 
(
	select l.*, i.createdat as InteractionDate,i.attemptrank,
		dispositionname, isnull(cdr.agent_no,l.InContactAgentID) as Acting_AgentID,
		class, start_date, agent_time, acw_time,contact_id,  First_name, Last_name, internalid,
		CalledPhone = case when contact_code > 100 then Ani_dialnum else contact_name end	,
		sb.[Lead Status], sb.[Lead Status Reason],
		p.productname, p.DiscountPrice,p.revenue,  o.productid
		,salerank = rank() over(partition by i.leadid order by  issale desc,i.createdat asc)		
	from
	(	
		select *, attemptrank = rank() over (partition by leadid order by createdat  asc)		
		from brightspeed.dbo.interactions i(nolock)  
		where CreatedAt between @StartDate and dateadd (day, 1, @EndDate)
		
	)i
		left join Brightspeed.dbo.Leads_CRM l (nolock)
			on l.leadid = i.leadid
		left join (
					select *,class = case when contact_code > 100 then 'IB'
										when contact_code < 100 then 'OB' 
										else 'NonCall' end
	
					from incontact_userhub.dbo.cdrplus cdr (nolock) 
					where campaign_name like '%bright%speed%' and start_date between @StartDate and dateadd (day, 1, @EndDate)
				)cdr on i.ContactID = cdr.contact_ID
		LEFT OUTER JOIN Brightspeed..Dispositions dd ON i.DispositionID = dd.DispositionID
		LEFT OUTER JOIN inContact_UserHub..Agents a (Nolock) ON isnull( i.InContactAgentID,l.incontactagentid)=a.agent_no
		full join brightspeed.dbo.orders o on l.leadid = o.leadid
		left join brightspeed.dbo.products p on o.productid = p.productID
		LEFT OUTER JOIN brightspeed.dbo.BrSpd_SubmittedSales sb (nolock) ON sb.Email = l.[Contact Email]
	where (dd.issale = 1  or (o.leadid is not null and o.active = 1 and dd.issale is null))
	and leadlistname not like '%testing%'
	and i.createdat between @startdate and dateadd(day, 1, @enddate)
)DS
WHERE salerank = 1
	--order by  cdr.contact_name
	order by calldate
option (recompile)
END

GO
