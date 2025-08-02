USE EcommerceOrderDB;

------------------      Basic Queries        ------------------

-- Total number of customers and distinct customers
SELECT 
    COUNT(*) AS TotalRecords, 
    COUNT(DISTINCT customer_id) AS DistinctCustomers 
FROM Customers;


-- Total customers by state
SELECT 
    Customer_state, 
    COUNT(customer_id) AS Total_customers
FROM Customers 
GROUP BY Customer_state
ORDER BY Total_customers DESC;


-- Number of distinct cities per state
SELECT 
    Customer_state, 
    COUNT(DISTINCT Customer_city) AS DistinctCities
FROM Customers
GROUP BY Customer_state 
ORDER BY DistinctCities DESC;


-- Top 5 most common cities and their states with customer counts
SELECT 
    Customer_city, 
    Customer_state, 
    COUNT(*) AS Total_customers 
FROM Customers
GROUP BY Customer_city, Customer_state 
ORDER BY Total_customers DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;


-- Count customers from a specific state (example: SP)
SELECT 
    COUNT(*) AS Total_Customers 
FROM Customers
WHERE Customer_state = 'SP';


-- Top 5 product categories
SELECT DISTINCT TOP 5 Product_category_name 
FROM Products;


-- Average shipping charge across order items
SELECT 
    AVG(Shipping_charges) AS Average_Shipping_Charge 
FROM OrderItems;


-- Most expensive products by price
SELECT TOP 5
    Product_id, 
    Price 
FROM OrderItems
ORDER BY Price DESC;



------------------      Joins & Insights        ------------------


-- Total amount (Price + Shipping) for each order (top 5)
SELECT TOP 5
    Order_id, 
    SUM(Price + Shipping_charges) AS Total_Price
FROM OrderItems 
GROUP BY Order_id
ORDER BY Total_Price DESC;


-- Customers who ordered most expensive items (top 10)
SELECT TOP 10
    OI.Order_id, 
    C.Customer_id, 
    SUM(OI.Price + OI.Shipping_charges) AS Total_Price
FROM OrderItems OI
JOIN Orders O ON O.Order_id = OI.Order_id 
JOIN Customers C ON C.Customer_id = O.Customer_id
GROUP BY OI.Order_id, C.Customer_id
ORDER BY Total_Price DESC;


-- Check if payment value matches product price + shipping per order
SELECT 
    O.Order_id,
    SUM(OI.Price + OI.Shipping_charges) AS Total_Price, 
    P.Payment_value AS Payment_Value
FROM Orders O
JOIN OrderItems OI ON O.Order_id = OI.Order_id
JOIN Payments P ON OI.Order_id = P.Order_id
GROUP BY O.Order_id, P.Payment_value
HAVING SUM(OI.Price + OI.Shipping_charges) != P.Payment_value;


-- Variation considering multiple payments per order
SELECT TOP 5
    O.Order_id,
    SUM(OI.Price + OI.Shipping_charges) AS Total_Price, 
    SUM(P.Payment_value) AS Payment_Value
FROM Orders O
JOIN OrderItems OI ON O.Order_id = OI.Order_id
JOIN Payments P ON OI.Order_id = P.Order_id
GROUP BY O.Order_id
HAVING SUM(OI.Price + OI.Shipping_charges) != SUM(P.Payment_value);


-- Customers with the most orders (top 5)
SELECT TOP 5 
    Customer_id, 
    COUNT(*) AS OrderCount
FROM Orders 
GROUP BY Customer_id
ORDER BY OrderCount DESC;


-- Cities generating highest total payment value (top 5)
SELECT TOP 5 
    C.Customer_city, 
    SUM(P.Payment_value) AS Total_Payment_Value
FROM Customers C
JOIN Orders O ON O.Customer_id = C.Customer_id
JOIN Payments P ON P.Order_id = O.Order_id
GROUP BY C.Customer_city
ORDER BY Total_Payment_Value DESC;


-- Cities placing the highest number of orders (top 5)
SELECT TOP 5 
    C.Customer_city, 
    COUNT(O.Order_id) AS Total_Orders
FROM Customers C
JOIN Orders O ON O.Customer_id = C.Customer_id
GROUP BY C.Customer_city
ORDER BY Total_Orders DESC;


-- Revenue collected from orders by month & year
SELECT 
    YEAR(O.Order_purchase_timestamp) AS Year,
    MONTH(O.Order_purchase_timestamp) AS Month,
    SUM(P.Payment_value) AS Total_Revenue
FROM Orders O 
JOIN Payments P ON O.Order_id = P.Order_id
GROUP BY YEAR(O.Order_purchase_timestamp), MONTH(O.Order_purchase_timestamp)
ORDER BY Year, Month;



------------------      Advanced SQL (Trends & Ranking with Window Functions, CTEs)        ------------------


-- Rank customers by total spending
SELECT 
    C.Customer_id, 
    SUM(P.Payment_value) AS Total_Spend, 
    RANK() OVER (ORDER BY SUM(P.Payment_value) DESC) AS Rank
FROM Customers C
JOIN Orders O ON C.Customer_id = O.Customer_id 
JOIN Payments P ON O.Order_id = P.Order_id
GROUP BY C.Customer_id
ORDER BY Total_Spend DESC;


-- Same query using CTE for clarity
WITH CustomerSpending AS (
    SELECT 
        C.Customer_id,
        SUM(P.Payment_value) AS TotalSpend
    FROM Customers C
    JOIN Orders O ON C.Customer_id = O.Customer_id
    JOIN Payments P ON O.Order_id = P.Order_id
    GROUP BY C.Customer_id
)
SELECT 
    Customer_id,
    TotalSpend,
    RANK() OVER (ORDER BY TotalSpend DESC) AS Rank
FROM CustomerSpending
ORDER BY TotalSpend DESC;


-- Top 5 sellers by total revenue (naive approach)
WITH SellerRevenue AS (
    SELECT 
        OI.Seller_id, 
        SUM(P.Payment_value) AS TotalRevenue
    FROM OrderItems OI
    JOIN Payments P ON OI.Order_id = P.Order_id
    GROUP BY OI.Seller_id
)
SELECT TOP 5
    Seller_id,
    TotalRevenue
FROM SellerRevenue 
ORDER BY TotalRevenue DESC;


-- Adjusting revenue proportionally if multiple sellers per order
WITH SellerCounts AS (
    SELECT 
        Order_id,
        COUNT(DISTINCT Seller_id) AS SellerCount
    FROM OrderItems
    GROUP BY Order_id
),
ProportionalRevenue AS (
    SELECT 
        OI.Seller_id,
        OI.Order_id,
        P.Payment_value / SC.SellerCount AS ProportionalPayment
    FROM OrderItems OI
    JOIN Payments P ON OI.Order_id = P.Order_id
    JOIN SellerCounts SC ON OI.Order_id = SC.Order_id
)
SELECT TOP 5
    Seller_id,
    SUM(ProportionalPayment) AS TotalRevenue
FROM ProportionalRevenue
GROUP BY Seller_id
ORDER BY TotalRevenue DESC;


-- Most expensive order per month
WITH OrderTotals AS (
    SELECT 
        O.Order_id,
        YEAR(O.Order_purchase_timestamp) AS Year,
        MONTH(O.Order_purchase_timestamp) AS Month,
        SUM(OI.Price + OI.Shipping_charges) AS TotalPrice
    FROM Orders O
    JOIN OrderItems OI ON O.Order_id = OI.Order_id
    GROUP BY O.Order_id, YEAR(O.Order_purchase_timestamp), MONTH(O.Order_purchase_timestamp)
),
RankedOrders AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY Year, Month 
            ORDER BY TotalPrice DESC
        ) AS rn
    FROM OrderTotals
)
SELECT Year, Month, Order_id, TotalPrice
FROM RankedOrders
WHERE rn = 1
ORDER BY Year, Month;


-- Products with highest total quantity sold
WITH CategorySales AS (
    SELECT 
        ISNULL(P.Product_category_name, 'unknown') AS ProductCategory,
        COUNT(OI.Product_id) AS TotalQuantity
    FROM OrderItems OI
    JOIN Products P ON OI.Product_id = P.Product_id
    GROUP BY ISNULL(P.Product_category_name, 'unknown')
),
RankedCategories AS (
    SELECT 
        ProductCategory,
        TotalQuantity,
        RANK() OVER (ORDER BY TotalQuantity DESC) AS CategoryRank
    FROM CategorySales
)
SELECT *
FROM RankedCategories
ORDER BY CategoryRank;


-- Monthly sales by product category with ranking
WITH MonthlyCategorySales AS (
    SELECT 
        YEAR(O.Order_purchase_timestamp) AS Year,
        MONTH(O.Order_purchase_timestamp) AS Month,
        ISNULL(P.Product_category_name, 'unknown') AS ProductCategory,
        COUNT(OI.Product_id) AS TotalCount
    FROM Orders O
    JOIN OrderItems OI ON O.Order_id = OI.Order_id
    JOIN Products P ON OI.Product_id = P.Product_id
    GROUP BY YEAR(O.Order_purchase_timestamp), MONTH(O.Order_purchase_timestamp), ISNULL(P.Product_category_name, 'unknown')
)
SELECT 
    Year,
    Month,
    ProductCategory,
    TotalCount,
    RANK() OVER (PARTITION BY Year, Month ORDER BY TotalCount DESC) AS CategoryRank
FROM MonthlyCategorySales
ORDER BY Year, Month, CategoryRank;


-- Revenue per product category with ranking
SELECT
    ISNULL(P.Product_category_name, 'unknown') AS ProductCategory,
    SUM(Py.Payment_value) AS TotalRevenue,
    RANK() OVER (ORDER BY SUM(Py.Payment_value) DESC) AS Rank
FROM Products P
JOIN OrderItems OI ON P.Product_id = OI.Product_id
JOIN Payments Py ON OI.Order_id = Py.Order_id
GROUP BY P.Product_category_name
ORDER BY TotalRevenue DESC;


-- Top 5 product categories by revenue using CTE
WITH CategoryRevenue AS (
    SELECT 
        ISNULL(P.Product_category_name, 'unknown') AS ProductCategory,
        SUM(Py.Payment_value) AS TotalRevenue,
        RANK() OVER (ORDER BY SUM(Py.Payment_value) DESC) AS Rank
    FROM Products P
    JOIN OrderItems OI ON P.Product_id = OI.Product_id
    JOIN Payments Py ON OI.Order_id = Py.Order_id
    GROUP BY P.Product_category_name
)
SELECT TOP 5 *
FROM CategoryRevenue
ORDER BY Rank;


-- Customer preferences by region (total revenue by state)
SELECT 
    C.Customer_state,
    SUM(P.Payment_value) AS TotalRevenue
FROM Customers C
JOIN Orders O ON C.Customer_id = O.Customer_id
JOIN Payments P ON O.Order_id = P.Order_id
GROUP BY C.Customer_state

ORDER BY TotalRevenue DESC;
