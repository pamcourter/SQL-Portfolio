USE [MockingJay]
GO
/****** Object:  StoredProcedure [dbo].[rs_Brightspeed_CallDetails]    Script Date: 1/5/2026 12:47:44 PM ******/
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
CREATE PROCEDURE [dbo].[rs_Brightspeed_CallDetails]
	-- Add the parameters for the stored procedure here
	@StartDate_p DATETIME,
	@EndDate_p DATETIME,
	@ContactID varchar(20) = null
	,@DispositionName varchar(100) = null
	,@LeadPhone varchar(10) = null
	

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


SELECT  i.createdat as CallDate, 
	l.LeadID, 
	AccountPhone = [Account Phone Number]
	,contact_ID	
	, Callback = DateAdd(HOUR,1,CallbackDateMST)
	, ContactName = [Contact First Name] + ' ' +  [Contact Last Name]
	, Interactions
	, Timezone
	, Comments = [Comments Log]
	, Gatekeeper = [Gatekeeper Name]
	, Disposition = DispositionName
	, l.InContactAgentID
	, AgentName=First_Name +' ' +Last_Name
	,employee_internal_id = internalid
	, start_date as LastCallDate

	, CalledPhone = case when contact_code > 100 then Ani_dialnum else contact_name end	
	, calltimestamp = dateadd(day, @TimeZoneadj,start_date)	

	, Calls = case when cdr.contact_id is not null then 1 else 0 end
	, connects = case when isconnect = 1 then 1 else 0 end
	, contact = case when iscontact = 1 then 1 else 0 end
	, Finalized =   case when dd.isFinal=1 then 1 else 0 end	
	, sale = case when issale = 1 then 1 else 0 end
	, agent_time
	, acw_time
	,l.Account#
	,l.[Location Account Name], l.[street address], l.city, l.state
	--, l.contact_first_name, l.contact_last_name, l.contact_email, l.contactType, l.contactPhone
	, AltPhone1, AltPhone2, AltPhone3
	, class = case when contact_code > 100 then 'IB' when contact_code < 100 then 'OB' else 'NonCall' end

FROM 
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


where (contact_id = @contactID or @contactID is null or @contactID = '') 
and (DispositionName = @DispositionName  or @DispositionName is null or @DispositionName = '')
and (case when contact_code > 100 then Ani_dialnum else contact_name end= @LeadPhone or [account phone number] = @LeadPhone or @LeadPhone is null or @LeadPhone = '')
order by l.leadid
--option (recompile)
END

GO
