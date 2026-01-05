#Brightspeed Outbound Sales reports

###Task-Create reports following specified formatting, to show outbound metrics such as lead count, dials, attempts and sales by list. The most complicated part on this was summing the attempts by day first, so that it shows at the time of the report

![Screenshot of Stats by List Report-Overall by list](../Brightspeed/Files/sbl_overal_attempts.png)
![Screenshot of Stats by List Report-By Day](../Brightspeed/Files/brightspeed_listdetails_day.png)\

[Sql SPs List Stats by Day/Week/Overall](/Brightspeed/Files/Brspd_ListDetailsbyDay_week_overall.sql)\


![Screenshot of Sales MRR in List Report](/Brightspeed/Files/sbl_salesdetails.png)\
[Sql sp for Sale details in List stats report](Brightspeed/Files/Brspd_SalesSummary.sql)\

###Report to show product sales with overall quantity and price

![Screenshot of Sales Product Details](/Brightspeed/Files/SaleDetails_products.png)\
[SQL code for Sales Products](/Brightspeed/Files/Brspd_SalesDetails.sql)\

###Report was requested to allow filtering by Record ID, Disposition of the call, or phone number to look up customer calls.

![Screenshot of Call Details](/Brightspeed/Files/calldetails_filters.png)\
[SQL code for Call Details](Brightspeed/Files/Brspd_CallDetails.sql)\

##Other Sql
Screenshot of a query developed to randomly assign a percentage of leads to a selectiong of agents. This enabled us to only assign some leads for agents to call while keeping the other leads unassigned until needed. 
![Screenshot of Stored Procedure for Assigning Agents](/Brightspeed/Files/brightspeed_assignagentsQuery.jpg)
