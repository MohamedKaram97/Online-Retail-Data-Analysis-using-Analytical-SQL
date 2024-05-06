--fist_question :
--basic queries :

--displaying every customer_id with his total number of invoices 
--To know how many invoices that each customer made : 

select customer_id , count(distinct invoice) as count_invoices
from tableRetail 
group by customer_id 
order by count_invoices desc ;

--displaying each invoice id with its amount of money and the customer who made it to know who made the highest invoices :

select distinct invoice , sum(price * quantity) as total_price , customer_id 
from tableRetail 
group by invoice , customer_id
order by total_price desc ;

--displaying each stock_code with its sold quantity to know which  stock items with has the  most quantity sold :

select distinct stockcode , sum(quantity)as count_items 
from tableRetail
group by stockcode
order by count_items desc ;

--analytical queries :

--displaying the top 10 customers ranked by every customer’s amount of money which has been spent in invoices 
--This will help us to know our loyal customers :

WITH RankedCustomers AS (
    SELECT  customer_id,  SUM(quantity * price) AS total_sales,
        RANK() OVER (ORDER BY SUM(quantity * price) DESC) AS customer_rank
    FROM   tableRetail
    GROUP BY   customer_id
)
SELECT   customer_id,  total_sales,  customer_rank
FROM  RankedCustomers
WHERE    customer_rank <= 10
ORDER BY  customer_rank;

--displaying the monthly spending amount for each customer and its accumulating sum to track the purchasing behavior of each customer over the months and notice if there any pattern in this behavior :

select customer_id , invoiceday , customer_sales , sum(customer_sales) over (partition by customer_id  order by invoiceday) as total_customer_sales 
 from 
(select customer_id , TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI'))  as  invoiceday ,  sum(quantity * price) as customer_sales
from tableRetail 
group by customer_id , TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI') )
order by customer_id , invoiceday ) 


--– tracking count of items sold of each stock item with an accumulative sum of it over months to notice if there any pattern in purchasing some stock items :

select stockcode , day , count_items_sold  ,
 sum(count_items_sold) over (partition by  stockcode  order by day asc )as total_count_items_sold
  from 
  
(select stockcode , TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI') )as day , sum (quantity) as count_items_sold 
from  tableRetail 
  group by stockcode  ,  TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI') ) ) ;

--displaying each day with its amount of sales to know the days with the highest amount of sales to detect if there is any pattern in them :

select   distinct TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI') ) as day  ,  
sum(quantity * price) over (partition by TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI') ) ) as day_sales 
from tableRetail 
order by day_sales desc ;


--displaying the count of customers who made transactions in each month and comparing it with the number of customers 
--who made transactions in the previous month .. this help us to track the change in customers count over months and know if thsis change is positive or negative :

with months_sales AS  (select  count (distinct customer_id) as count_customers ,  TO_CHAR(TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI')), 'MM/YYYY') as month 
from tableRetail
group by  TO_CHAR(TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI')), 'MM/YYYY'))


select month  , count_customers  , (count_customers -lag(count_customers) over (order by to_date(month , 'MM/YYYY'))) as change_customers
from months_sales 
order by to_date(month , 'MM/YYYY')asc ;

--displaying each month with its number of invoices and amount of sales and comparing it with the running maximum sales 
--and the running minimum sales over months .. it will help us to assess the amount of achieved sales in each month :

with months_sales AS  (select sum(quantity * price) as sales ,  TO_CHAR(TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI')), 'MM/YYYY') as month ,
 count(distinct invoice) as count_invoices 
from tableRetail
group by  TO_CHAR(TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI')), 'MM/YYYY'))


select month  ,count_invoices ,    sales , Max(sales) over(order by  to_date(month , 'MM/YYYY')asc ) as max_sales , Min(sales) over(order by  to_date(month , 'MM/YYYY')asc )  as min_sales
from months_sales 
order by to_date(month , 'MM/YYYY')asc ;


--I noticed change in the price of some items so I wrote this query to track the change in prices .. if the item has only one price then it will be displayed .. 
--if the item has multiple prices then each one of them will be displayed with the last date of applying each price before changing it :

select stockcode , price , day from (
select distinct stockcode , price ,  lead (price) over(partition by stockcode order by TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI')) ) as coming_price  ,TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI'))  as day
from tableRetail 
order by stockcode , day asc )
where price <> coming_price  ; 

--I noticed there are gaps among some dates so it means there are some without any transaction.. 
--so I tried to get every gap among dates and ordered them to know the longest gaps to analyze why our sales stopped in these intervals  :

select day  ,  next_day  , (next_day - day) as difference 
from (
select  distinct TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI') ) as day  , 
lead ( TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI') )  ) over (order by  TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI') ) asc ) as next_day
from tableRetail  )  
where day <> next_day 
order by difference desc  ;


--– I wanted to classify the customers based on their max count of days without making any transactions .. 
--I calculated average of gaps between purchasing days for all customers and I got 33 
--Then I compared it with the maximum of gap days for each customer and based on the result of this comparison
 --I gave a value (consistent) or (inconsistent) to represent the status of each customer’s purchasing behavior : 

WITH sequential_days AS (
    SELECT  customer_id,    TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI')) AS day,
        LEAD(TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI'))) OVER (PARTITION BY customer_id ORDER BY TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI'))) AS next_day
    FROM     tableRetail ), 
difference_between_days AS (
    SELECT   customer_id,   day,   next_day, 
        MAX(next_day - day) over (partition by customer_id ) AS max_gap, 
        round(AVG(next_day - day) OVER () )AS avg_gap
    FROM     sequential_days 
    WHERE   day <> next_day )
SELECT   distinct customer_id,   max_gap,    avg_gap ,
    CASE    WHEN max_gap > avg_gap THEN 'inconsistent'
        ELSE 'consistent'
    END AS customer_status 
FROM    difference_between_days  ;


--second question :

With customer_sales as (select  customer_id , sum(price * quantity) as sum_sales from tableRetail 
group by customer_id)  ,
 RFM as (select customer_id , 
 round ( (   (select  max( TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI')) ) as last_date from tableRetail ) - max( TRUNC(TO_DATE(invoicedate, 'MM/DD/YYYY HH24:MI')) ) ) , 0 ) as recency , 
count(customer_id) as frequency , round( percent_rank() over ( order by sum (quantity * price )) , 2) as monetary  from tableRetail
group by customer_id ),

RFM_scores as ( 
select customer_id, recency, frequency, monetary, ntile(5) over (order by recency) as r_score, 
ntile(5) over (order by frequency + monetary) as fm_score 
from RFM )
select customer_id, recency, frequency, monetary,  r_score,  fm_score ,  
case 
when (r_score >= 5 and fm_score >= 5) 
or (r_score >= 5 and fm_score = 4) 
or (r_score = 4 and fm_score >= 5) then 'champions' 
when (r_score >= 5 and fm_score = 2) 
or (r_score = 4 and fm_score = 2) 
or (r_score = 3 and fm_score = 3) 
or (r_score = 4 and fm_score >= 3) then 'potential 
loyalists' 
when (r_score >= 5 and fm_score = 3) 
or (r_score = 4 and fm_score = 4) 
or (r_score = 3 and fm_score >= 5) 
or (r_score = 3 and fm_score >= 4) then 'loyal 
customers' 
when r_score >= 5 and fm_score = 1 then 'recent 
customers' 
when (r_score = 4 and fm_score = 1) 
or (r_score = 3 and fm_score = 1) then 'promising' 
when (r_score = 3 and fm_score = 2) 
or (r_score = 2 and fm_score = 3) 
or (r_score = 2 and fm_score = 2) then 'customers 
needing attention' 
when (r_score = 2 and fm_score >= 5) 
or (r_score = 2 and fm_score = 4) 
or (r_score = 1 and fm_score = 3) then 'at risk' 
when (r_score = 1 and fm_score >= 5) 
or (r_score = 1 and fm_score = 4) then 'cant lose 
them' 
when (r_score = 1 and fm_score = 2) 
or (r_score = 2 and fm_score = 1) then 'hibernating' 
when r_score = 1 and fm_score <= 1 then 'lost' 
else 'other' 
end as cust_segment from RFM_scores ;



--third question : 
--first part :

WITH customer_dates AS (
    SELECT cust_id,
        TO_DATE(calendar_dt, 'YYYY-MM-DD') AS date_value,
        ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY TO_DATE(calendar_dt, 'YYYY-MM-DD')) AS rn
    FROM    test
) , 
customer_intervals as (
SELECT  cust_id,  MIN(date_value) AS start_date,
    MAX(date_value) AS end_date,
    COUNT(*) AS sequential_days
FROM (
    SELECT   cust_id,   date_value,   date_value - rn AS grp
    FROM  customer_dates
)

GROUP BY cust_id, grp
ORDER BY  cust_id,  start_date )
    select cust_id , max(sequential_days) as max_sequence from customer_intervals
    group by cust_id  ;
    

--second part :

with customers_sales as (select cust_id , calendar_dt ,count(calendar_dt) over (partition by cust_id order by TO_DATE(calendar_dt, 'YYYY-MM-DD')) as count_days , amt_l ,
sum(amt_l) over (partition by cust_id order by TO_DATE(calendar_dt, 'YYYY-MM-DD')) as total_amount
from test ) ,

high_amounts as (
select cust_id , count_days ,total_amount from customers_sales
where total_amount >=250 ) 

select round ( avg (count_days) )as avg_days from high_amounts
where (cust_id, total_amount) IN (select cust_id , min(total_amount) from high_amounts
group by cust_id)
order by cust_id ;

