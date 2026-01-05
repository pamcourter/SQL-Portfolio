
/****** Object:  StoredProcedure [dbo].[rs_BrightSpeed_OB_ListStats_day]    Script Date: 1/5/2026 12:47:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Pam
-- Create date: 7/11/25
-- Description:	<list stats by day>
-- ===========================================
CREATE PROCEDURE [dbo].[rs_BrightSpeed_OB_ListStats_day]
	@StartDate_p datetime,
	@EndDate_p datetime
	
AS
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @StartDate DATETIME = @StartDate_P 
	DECLARE @EndDate DATETIME = @EndDate_p 	

;
With 

listcount as 
(
		select leadlistname, count(*) as LeadCount,
			convert(varchar, max(CreatedAt),101) as Leaddate,
			sum(case when issuppressed = 1 then 1 else 0 end) as suppressed
		from brightspeed..leads_crm 
		group by leadlistname
),
interactions as
(
	SELECT 
		l.LeadID, l.LeadListName
		,CallDate = convert(varchar,  isnull(cdr.[start_date], i.createdat),101) 
		, cdr.Skill_name
		, dateOfCall = DateAdd(hour,1,i.CreatedAt)
		,start_date, cdr.contact_id	
		, l.State, l.City--, l.Zipcode
		, l.[Account Phone Number] 
		, Areacode = SUBSTRING(cdr.contact_name,1,3) 
		, Prefix = SUBSTRING(cdr.contact_name,4,3) 
		, timeZone 
		, isDial = 1
		, isconnect = cast(dd.isconnect as int)
		, iscontact = cast(dd.iscontact as int)
		, isfinal = cast(dd.isfinal as int)
		, isDNC = cast(dd.isDNC as int)
		, isSale = cast(dd.isSale as int)
		, Agenttime = cdr.agent_time
		, acw_time = cdr.ACW_Time
		, isnull(cdr.agent_no, l.incontactagentid) as agent_no
		,lastIntRank = rank() over(partition by i.leadid,convert(varchar, cdr.[start_date],101)   order by i.createdat desc) 
		, DispositionName
	FROM Brightspeed..Interactions i (nolock)
	JOIN Brightspeed..Leads_CRM l (nolock) ON i.leadid = l.leadid 
	left JOIN (
					select * from inContact_UserHub..CDRPlus cdr (nolock) 
					where start_date between @StartDate and dateadd(day, 1, @Enddate)
				)cdr ON i.ContactID = cdr.contact_id
	LEFT OUTER JOIN Brightspeed..Dispositions dd ON i.DispositionID = dd.DispositionID
	WHERE 
		i.CreatedAt between @StartDate and DateAdd(day,1,@EndDate)
		AND LeadListName NOT LIKE '%Testing%'
),

FollowUpDispo as
(
	select leadlistname, calldate,count(*) as followUpCnt from interactions
	where lastIntRank = 1 and dispositionName = 'DM Contact - Follow Up Scheduled'
	group by LeadListName, calldate
	
),
attempts as
	(
		
	select  leadlistname, calldate,
			sum(case when Maxattemptrank = 1 then 1 else 0 end) as attempts1, 
			sum(case when Maxattemptrank = 2 then 1 else 0 end) as attempts2,
			sum(case when Maxattemptrank = 3 then 1 else 0 end) as attempts3,
			sum(case when Maxattemptrank = 4 then 1 else 0 end) as attempts4,
			sum(case when Maxattemptrank = 5 then 1 else 0 end) as attempts5,
			sum(case when Maxattemptrank >= 6 then 1 else 0 end) as attempts6
			,sum(case when LeadFinalCount = 0 and Maxattemptrank >= 6 then 1 else 0 end) as Nonfinal6Attempt
		from 
		(

			select leadlistname, leadid, calldate,max(attemptrank) as Maxattemptrank, sum(isfinal) as LeadFinalCount
			from 
			(
				select  Leadid, leadlistname, calldate, [account phone number],isFinal,					
					attemptrank = rank() over (partition by leadid, leadlistname order by start_date  asc)					
					from interactions 
					where contact_id is not null and isconnect = 1
					
			)x
			group by leadlistname,calldate, leadid	
	)y 
		
	group by leadlistname, calldate


	)



,c as 
	(
		SELECT 
			calldate,			
			datename(weekday, calldate) as CallDayName,
			LeadListName
			, sum(isDial) as DIals
			, sum(isconnect) as Connections
			, sum(iscontact) as contacts
			, sum(isfinal) as Finalized
			, sum(isDNC)  as DNC
			, sum(isSale) as sales
			, Agenttime = sum(agenttime)
			, acw_time = sum(ACW_Time)
			, count (distinct isnull(agent_no,0)) as ActiveAgents
		from Interactions
		group by calldate, leadlistname
	)

,cdrcombDay as 
(
	select  calldate, sum(dials) as overalldials
	from c
	group by calldate
)

, h as 
	(
		Select leadlistname, c.calldate, callPerc = dials/(overalldials*1.0)
				, (totaltime * (dials/(overalldials*1.0))) as sec_byPerc
		from 
		(
			SELECT convert(varchar, callday,101) as callday	
				,totaltime = sum(totaltime-unavailableTime) --productive		
			FROM Nest.dbo.ProjectTimeByHalfHour (nolock) h
			WHERE CallDay BETWEEN @StartDate AND dateadd(day, 1,@EndDate) 
				AND (CampaignID = 9313211 or teamname like '%brightspeed%')		
			GROUP BY convert(varchar, callday,101)
		)ht left join cdrcombDay on ht.callday = cdrcombDay.calldate
		left join c on ht.callday = c.calldate
		
	)



select ch.*, LeadCount,attempts1,attempts2,attempts3,attempts4,attempts5,attempts6, 
		Nonfinal6Attempt, followUpCnt, suppressed, leaddate
from
(
	select c.LeadListName, c.calldate, CallDayName
				, sum(Dials) as DIals
				, sum(connections) as Connections
				, sum(contacts) as contacts
				, sum(finalized) as Finalized
				, sum(DNC)  as DNC
				, sum(Sales) as sales
				, Agenttime = sum(agenttime)/3600.0
				, acw_time = sum(ACW_Time)/3600.0
				, sum(sec_byPerc)/3600.0 as Hours_byPerc 
				, sum(ActiveAgents) as ActiveAgents
				, sum(Sales)/(sum(ActiveAgents)*1.00) as salesbyAgentD
	from c left join h on c.leadlistname = h.LeadListName and c.calldate = h.calldate
	group by c.leadlistname, c.calldate,CallDayName
)ch

left join ListCount on ch.leadlistname = listcount.leadlistname
left join attempts on ch.LeadListName = attempts.LeadListName and ch.calldate = attempts.calldate
left join FollowUpDispo on ch.leadlistname = FollowUpDispo.leadlistname and ch.callDate=FollowUpDispo.calldate

order by Leadlistname, calldate

	--option(recompile)
END
GO
/****** Object:  StoredProcedure [dbo].[rs_BrightSpeed_OB_ListStats_Week]    Script Date: 1/5/2026 12:47:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Pam
-- Create date: 7/11/25
-- Description:	<list stats by week>
-- =============================================
CREATE PROCEDURE [dbo].[rs_BrightSpeed_OB_ListStats_Week]
	@StartDate_p datetime,
	@EndDate_p datetime
	
AS
BEGIN	
	SET NOCOUNT ON;
	DECLARE @StartDate DATETIME = @StartDate_P 
	DECLARE @EndDate DATETIME = @EndDate_p 

;

With 
	listcount as 
	(
			select leadlistname, convert(varchar, max(CreatedAt),101) as Leaddate,
					count(*) as LeadCount, 
					sum(case when active =1 then 1 else 0 end) as ActiveLeads, 
					sum(case when issuppressed = 1 then 1 else 0 end) as suppressed
					, sum(case when isfinal = 1 then 1 else 0 end) as FinalizedLead
					, sum(case when isDNC = 1 then 1 else 0 end) as DNCLead		
			from brightspeed..leads_crm 
			group by leadlistname
	)

,interactions as
(
	SELECT 
	 WeekDate= datepart(week,  isnull(cdr.[start_date], i.createdat)) ,
	 WeekName = convert(varchar,DATETRUNC(week,  isnull(cdr.[start_date], i.createdat)) , 101) ,
		--	YearDate = datename(Year, start_date),
		l.LeadID, l.LeadListName
		,CallDate = convert(varchar, isnull(cdr.[start_date], i.createdat),101) 
		, cdr.Skill_name
		, dateOfCall = DateAdd(hour,1,i.CreatedAt)
		,start_date, cdr.contact_id	
		, l.State, l.City--, l.Zipcode
		, l.[Account Phone Number] 
		, Areacode = SUBSTRING(cdr.contact_name,1,3) 
		, Prefix = SUBSTRING(cdr.contact_name,4,3) 
		, timeZone 
		, isDial = 1
		, isconnect = cast(dd.isconnect as int)
		, iscontact = cast(dd.iscontact as int)
		, isfinal = cast(dd.isfinal as int)
		, isDNC = cast(dd.isDNC as int)
		, isSale = cast(dd.isSale as int)
		, Agenttime = cdr.agent_time
		, acw_time = cdr.ACW_Time
		, isnull(cdr.agent_no, l.incontactagentid) as agent_no
		,lastIntRank = rank() over(partition by i.leadid,datepart(week, start_date)  order by i.createdat desc) 
		, DispositionName
	FROM Brightspeed..Interactions i (nolock)
	JOIN Brightspeed..Leads_CRM l (nolock) ON i.leadid = l.leadid 
	left JOIN (
					select * from inContact_UserHub..CDRPlus cdr (nolock) 
					where start_date between @StartDate and dateadd(day, 1, @Enddate)
				)cdr ON i.ContactID = cdr.contact_id
	LEFT OUTER JOIN Brightspeed..Dispositions dd ON i.DispositionID = dd.DispositionID
	WHERE i.InteractionTypeID = 1
		AND i.CreatedAt between @StartDate and DateAdd(day,1,@EndDate)
		AND LeadListName NOT LIKE '%Testing%'
),
leadstouched as 
(
	select leadlistName, weekdate, count (distinct leadid) as touchedLeads, count(distinct agent_no) as DistinctAgents
	from interactions --where contacT_id is not null
	group by leadlistname, weekdate
	),
FollowUpDispo as
(
	select leadlistname, weekdate,count(*) as followUpCnt from interactions
	where lastIntRank = 1 and dispositionName = 'DM Contact - Follow Up Scheduled'
	group by LeadListName, weekdate
	
),
attempts as 
	(
		
	select  leadlistname, weekdate,
			sum(case when Maxattemptrank = 1 then 1 else 0 end) as attempts1, 
			sum(case when Maxattemptrank = 2 then 1 else 0 end) as attempts2,
			sum(case when Maxattemptrank = 3 then 1 else 0 end) as attempts3,
			sum(case when Maxattemptrank = 4 then 1 else 0 end) as attempts4,
			sum(case when Maxattemptrank = 5 then 1 else 0 end) as attempts5,
			sum(case when Maxattemptrank >= 6 then 1 else 0 end) as attempts6
			,sum(case when LeadFinalCount = 0 and Maxattemptrank >= 6 then 1 else 0 end) as Nonfinal6Attempt
		from 
		(

			select leadlistname, leadid, weekdate, max(attemptrank) as Maxattemptrank, sum(isfinal) as LeadFinalCount
			from 
			(
				select  Leadid, leadlistname, calldate, weekdate,[account phone number],isFinal,					
					attemptrank = rank() over (partition by leadid, leadlistname order by start_date  asc)					
					from interactions 
					where contact_id is not null and isconnect = 1
					
			)x
			group by leadlistname, leadid,weekdate	
	)y 		
	group by leadlistname, weekdate


),


cmini as --this is to get a distinct finalized lead count per week rather than count finalized dispositions
	( 
		select Weekdate, leadlistname, 
		sum(case when finalized > 0 then 1 else 0 end) as Finalized
		,sum(case when LeadSales > 0 then 1 else 0 end) as Sales
		,sum(case when Dnc > 0 then 1 else 0 end) as DNC
		from 
			(
				SELECT 	calldate,	weekdate,WeekName,
						LeadListName, leadid			
						, sum(isfinal) as Finalized
						, sum(isDNC)  as DNC
						, sum(isSale) as Leadsales			
				from Interactions
				group by leadlistname, calldate, weekdate,WeekName, leadid
			)sl
		group by leadlistname, weekdate
	),
		

c as --get totals by calldate so we can get a better percentage of calls by day for the hours breakdown by list
	(
		SELECT 		calldate,	weekdate,WeekName,
			LeadListName
			, sum(isDial) as DIals
			, sum(isconnect) as Connections
			, sum(iscontact) as contacts			
			, sum(isSale) as sales
			, Agenttime = sum(agenttime)
			, acw_time = sum(ACW_Time)
			, count (distinct agent_no) as ActiveAgents
		from Interactions
		group by leadlistname, calldate, weekdate,WeekName
	)

	
,cdrcombDay as --total dials per day for percentage calculation
(
	select  calldate, sum(dials) as overalldials
	from c
	group by calldate
)


, h as --hours from project time by half hour, combined with c and cdrcombday to break hours by percentage of dials
	(
		Select leadlistname, c.calldate, callPerc = dials/(overalldials*1.0)
				, (totaltime * (dials/(overalldials*1.0))) as sec_byPerc
		from 
		(
			SELECT convert(varchar, callday,101) as callday	
				,totaltime = sum(totaltime-unavailableTime) --productive		
			FROM Nest.dbo.ProjectTimeByHalfHour (nolock) h
			WHERE CallDay BETWEEN @StartDate AND dateadd(day, 1,@EndDate) 
				AND (CampaignID = 9313211 or teamname like '%brightspeed%')		
			GROUP BY convert(varchar, callday,101)
		)ht left join cdrcombDay on ht.callday = cdrcombDay.calldate
		left join c on ht.callday = c.calldate
		
	)
	
	
	

select ch.*, LeadCount,attempts1,attempts2,attempts3,attempts4,attempts5,attempts6, 
		Nonfinal6Attempt, followUpCnt, suppressed, LeadDate, Finalized, DistinctAgents
from
(
	select c.LeadListName, c.weekdate,WeekName
				, sum(Dials) as dials
				, sum(connections) as connections
				, sum(contacts) as contacts				
				, sum(Sales) as sales
				, Agenttime = sum(agenttime)/3600.0
				, acw_time = sum(ACW_Time)/3600.0
				, sum(sec_byPerc)/3600.0 as Hours_byPerc 
				,sum(activeagents) as ActiveAgents
				,sum(sales)/(sum(activeagents)*1.00) as SalesbyAgent
				
	from c left join h on c.leadlistname = h.LeadListName and c.calldate = h.calldate
	
	group by c.leadlistname, c.weekdate,WeekName
)ch

left join ListCount on ch.leadlistname = listcount.leadlistname 
left join attempts on ch.LeadListName = attempts.LeadListName and ch.weekdate = attempts.WeekDate 
left join FollowUpDispo on ch.leadlistname = FollowUpDispo.leadlistname and ch.WeekDate=FollowUpDispo.weekdate
left join cmini on cmini.leadlistname = ch.leadlistname and cmini.weekdate = ch.weekdate
left join leadstouched lt on lt.weekdate = ch.weekdate and lt.LeadListName=ch.LeadListName
order by Leadlistname ,weekdate

	--option(recompile)
END
GO
/****** Object:  StoredProcedure [dbo].[rs_BrightSpeed_OB_ListStatsAll]    Script Date: 1/5/2026 12:47:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Pam
-- Create date: 7/11/25
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[rs_BrightSpeed_OB_ListStatsAll]
	@StartDate_p datetime,
	@EndDate_p datetime
	
AS
BEGIN
	
	SET NOCOUNT ON;
	DECLARE @StartDate DATETIME = @StartDate_P 
	DECLARE @EndDate DATETIME = @EndDate_p 

;
With 
listcount as 
(
		select leadlistname, convert(varchar, max(CreatedAt),101) as Leaddate,
				count(*) as LeadCount, 
				sum(case when active =1 then 1 else 0 end) as ActiveLeads, 
				sum(case when issuppressed = 1 and isfinal <> 1 then 1 else 0 end) as suppressed
				, sum(case when isfinal = 1 then 1 else 0 end) as FinalizedLead
				, sum(case when isDNC = 1 then 1 else 0 end) as DNCLead	
				,sum(case when isduplicate = 1 then 1 else 0 end) as DuplicateLead
		from brightspeed..leads_crm 
		group by leadlistname
)

,interactions as
(
	SELECT 
	 
		l.LeadID, l.LeadListName
		,CallDate = convert(varchar,  isnull(cdr.[start_date], i.createdat),101) 
		, cdr.Skill_name
		, dateOfCall = DateAdd(hour,1,i.CreatedAt)
		, start_date, cdr.contact_id		
		, l.State, l.City--, l.Zipcode
		, l.[Account Phone Number] 
		, Areacode = SUBSTRING(cdr.contact_name,1,3) 
		, Prefix = SUBSTRING(cdr.contact_name,4,3) 
		, timeZone 
		, isDial = 1
		, isconnect = cast(dd.isconnect as int)
		, iscontact = cast(dd.iscontact as int)
		, isfinal = cast(dd.isfinal as int)
		, isDNC = cast(dd.isDNC as int)
		, isSale = cast(dd.isSale as int)
		, Agenttime = cdr.agent_time
		, acw_time = cdr.ACW_Time
		, isnull(cdr.agent_no, l.incontactagentid) as agent_no
		, lastIntRank = rank() over(partition by i.leadid order by i.createdat desc) 
		, DispositionName
		
	FROM Brightspeed..Interactions i (nolock)
	JOIN Brightspeed..Leads_CRM l (nolock) ON i.leadid = l.leadid 
	left JOIN (
					select * from inContact_UserHub..CDRPlus cdr (nolock) 
					where start_date between @StartDate and dateadd(day, 1, @Enddate)
				)cdr  ON i.ContactID = cdr.contact_id
	LEFT OUTER JOIN Brightspeed..Dispositions dd ON i.DispositionID = dd.DispositionID
	WHERE 
		 i.CreatedAt between @StartDate and DateAdd(day,1,@EndDate)
		AND LeadListName NOT LIKE '%Testing%'
),
leadstouched as 
(
	select leadlistName, count (distinct leadid) as touchedLeads, count(distinct agent_no) as DistinctAgents
	from interactions 
	group by leadlistname
	),
	
leadsUntouched as 
(
	select l.leadlistName,  count(*) as NoInteractionLeadcnt
	from brightspeed.dbo.leads_crm l (nolock) 
	left join interactions i on l.leadid = i.leadid 	
	where i.leadID is null and isnull(l.isduplicate,0) <> 1  and isnull(l.IsSuppressed,0) <> 1
	group by l.leadlistname
),
FollowUpDispo as
(
	select leadlistname, count(*) as followUpCnt from interactions
	where lastIntRank = 1 and dispositionName = 'DM Contact - Follow Up Scheduled'
	group by LeadListName
	
),

attempts as
	(
		
		select  leadlistname, 
				sum(case when Maxattemptrank = 1 then 1 else 0 end) as attempts1, 
				sum(case when Maxattemptrank = 2 then 1 else 0 end) as attempts2,
				sum(case when Maxattemptrank = 3 then 1 else 0 end) as attempts3,
				sum(case when Maxattemptrank = 4 then 1 else 0 end) as attempts4,
				sum(case when Maxattemptrank = 5 then 1 else 0 end) as attempts5,
				sum(case when Maxattemptrank >= 6 then 1 else 0 end) as attempts6
				,sum(case when LeadFinalCount = 0 and Maxattemptrank >= 6 then 1 else 0 end) as Nonfinal6Attempt
			from 
			(

				select leadlistname, leadid, max(attemptrank) as Maxattemptrank, sum(isfinal) as LeadFinalCount
				from 
				(
					select  Leadid, leadlistname, calldate, [account phone number],isFinal,					
						attemptrank = rank() over (partition by leadid, leadlistname order by start_date  asc)					
						from interactions 
						where contact_id is not null and isconnect = 1
					
				)x
				group by leadlistname, leadid	
		)y 
		
		group by leadlistname
	)
,
c as 
	(
		SELECT 		calldate,	
			LeadListName
			, sum(isDial) as DIals
			, sum(isconnect) as Connections
			, sum(iscontact) as contacts
			, sum(isfinal) as Finalized
			, sum(isDNC)  as DNC
			, sum(isSale) as sales
			, Agenttime = sum(agenttime)
			, acw_time = sum(ACW_Time)
			, count (distinct agent_no) as ActiveAgents
		from Interactions
		group by leadlistname, calldate
	)

	
,cdrcombDay as 
	(
		select  calldate, sum(dials) as overalldials
		from c
		group by calldate
	)


, h as 
	(
		Select leadlistname, c.calldate, callPerc = dials/(overalldials*1.0)
				, (totaltime * (dials/(overalldials*1.0))) as sec_byPerc
		from 
		(
			SELECT convert(varchar, callday,101) as callday	
				,totaltime = sum(totaltime-unavailableTime) --productive		
			FROM Nest.dbo.ProjectTimeByHalfHour (nolock) h
			WHERE CallDay BETWEEN @StartDate AND dateadd(day, 1,@EndDate) 
				AND (CampaignID = 9313211 or teamname like '%brightspeed%')		
			GROUP BY convert(varchar, callday,101)
		)ht left join cdrcombDay on ht.callday = cdrcombDay.calldate
		left join c on ht.callday = c.calldate
		
	)--,


select ch.*, LeadCount,attempts1,attempts2,attempts3,attempts4,attempts5,attempts6, 
			Nonfinal6Attempt,followUpCnt, suppressed, ActiveLeads,touchedLeads,NoInteractionLeadcnt, Leaddate
			,FinalizedLead,DNCLead,DuplicateLead,distinctAgents, @StartDate as StartDate, @EndDate as EndDate
from
(
	select c.LeadListName
				, sum(Dials) as dials
				, sum(connections) as connections
				, sum(contacts) as contacts
				, sum(finalized) as finalized
				, sum(DNC)  as DNC
				, sum(Sales) as sales
				, Agenttime = sum(agenttime)/3600.0
				, acw_time = sum(ACW_Time)/3600.0
				, sum(sec_byPerc)/3600.0 as Hours_byPerc 
				,sum(activeagents) as ActiveAgents
				,sum(sales)/(sum(activeagents)*1.00) as SalesbyAgent
				
	from c left join h on c.leadlistname = h.LeadListName and c.calldate = h.calldate	
	group by c.leadlistname
)ch

left join ListCount on ch.leadlistname = listcount.leadlistname
left join attempts on ch.LeadListName = attempts.LeadListName 
left join FollowUpDispo on ch.leadlistname = FollowUpDispo.leadlistname
left join leadstouched on ch.leadlistname = leadstouched.leadlistname
left join leadsUntouched on ch.leadlistname = leadsUntouched.leadlistname 
order by Leadlistname


END
GO
