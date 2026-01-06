# Brightspeed Outbound Sales reports

### Task-Create reports following specified formatting
#### show outbound metrics such as lead count, dials, attempts and sales by list. 

![Screenshot of Stats by List Report-Overall by list](../Brightspeed/Files/sbl_overal_attempts.png)
![Screenshot of Stats by List Report-By Day](../Brightspeed/Files/brightspeed_listdetails_day.png)

[Sql SPs List Stats by Day/Week/Overall](..//Brightspeed/Files/Brspd_ListDetailsbyDay_week_overall.sql)

------------------------------------------
![Screenshot of Sales MRR in List Report](..//Brightspeed/Files/sbl_salesdetails.png)
[Sql sp for Sale details in List stats report](../Brightspeed/Files/Brspd_SalesSummary.sql)

##### I struggled with the attempts because I wasn't sure whether they wanted a total number of calls (attempts) made at the end of the period or if they wanted a sum of how many leads were at each attempt category (if a call was made twice, it would have 2 attempts that day, so attempts2 would be 1 for that phone number). I attempted both and compared with excel to ensure the counts were correct and presented both options to the operations director. 
-----------------------------------------------------------------------------------------------------------------
### Report to show product sales with overall quantity and price

![Screenshot of Sales Product Details](..//Brightspeed/Files/SaleDetails_products.png)
[SQL code for Sales Products](..//Brightspeed/Files/Brspd_SalesDetails.sql)

-----------------------------------------------------------------------------------------------------------------
### Report was requested to allow filtering by Record ID, Disposition of the call, or phone number to look up customer calls.

![Screenshot of Call Details](..//Brightspeed/Files/calldetails_filters.png)
[SQL code for Call Details](../Brightspeed/Files/Brspd_CallDetails.sql)

#### I included the filters in the report parameters in order to bypass them (parameter = null) if no filter was selected.
-----------------------------------------------------------------------------------------------------------------
## Other Sql
Screenshot of a query developed to randomly assign a percentage of leads to a selectiong of agents. This enabled us to only assign some leads for agents to call while keeping the other leads unassigned until needed. 
![Screenshot of Stored Procedure for Assigning Agents](..//Brightspeed/Files/brightspeed_assignagentsQuery.jpg)
