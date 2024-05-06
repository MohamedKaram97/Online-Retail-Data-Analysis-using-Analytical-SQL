/* For the online retail data */
CREATE TABLE tableRetail 
(
    Invoice	VARCHAR(50),
    StockCode	VARCHAR(50),
    Quantity	INT,
    InvoiceDate	VARCHAR(50),
    Price	FLOAT,
    Customer_ID	VARCHAR(50),
    Country	VARCHAR(50)
);

/* For the daily purchasing data */
CREATE TABLE dailyPurchasing 
(
    Cust_Id	VARCHAR(50),
    Calendar_Dt VARCHAR(50),
    Amt_LE	FLOAT
);