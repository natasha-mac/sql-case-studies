CREATE DATABASE dannys_dinner;
USE dannys_dinner;

CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INT
);

INSERT INTO sales VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
  
CREATE TABLE menu (
  product_id INT,
  product_name VARCHAR(5),
  price INT
);

INSERT INTO menu VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  
CREATE TABLE members (
  customer_id VARCHAR(1),
  join_date DATE
);

INSERT INTO members VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
 
SELECT * FROM  members;
SELECT * FROM menu;
SELECT * FROM sales;

-- What is the total amount each customer spent at the restaurant?
SELECT s.customer_id, SUM(m.price)
FROM sales AS s
LEFT JOIN menu AS m 
ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(DISTINCT order_date)
FROM sales
GROUP BY customer_id;

-- What was the first item from the menu purchased by each customer?
WITH first_purchase AS (
	SELECT s.customer_id, m.product_name, ROW_NUMBER() OVER (PARTITION BY s.customer_id) AS x
	FROM sales AS s
	LEFT JOIN menu AS m
	ON s.product_id = m.product_id
	WHERE s.order_date = (
		SELECT MIN(order_date)
		FROM sales
))

SELECT customer_id, product_name
FROM first_purchase
WHERE x = 1;

-- What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT m.product_name, COUNT(s.product_id) as purchased
FROM sales AS s
LEFT JOIN menu AS m
ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY purchased DESC
LIMIT 1;

-- Which item was the most popular for each customer?
WITH most_purchased AS (
	SELECT s.customer_id, COUNT(s.product_id) AS purchases, m.product_name, DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(s.product_id) DESC) AS x
    FROM sales AS s
    LEFT JOIN menu AS m
    ON s.product_id = m.product_id
    GROUP BY s.customer_id, m.product_name
)

SELECT customer_id, product_name, purchases
FROM most_purchased
WHERE x = 1;

-- Which item was purchased first by the customer after they became a member?
WITH first_member_purchase AS (
	SELECT mem.customer_id, m.product_name, ROW_NUMBER() OVER (PARTITION BY mem.customer_id ORDER BY s.order_date ASC) AS x
    FROM sales AS s
    LEFT JOIN members AS mem
    ON s.customer_id = mem.customer_id
    LEFT JOIN menu AS m
    ON s.product_id = m.product_id
    WHERE s.order_date >= mem.join_date
)

SELECT customer_id, product_name
FROM first_member_purchase
WHERE x = 1;

-- Which item was purchased just before the customer became a member?
WITH non_member_purchases AS (
	SELECT s.customer_id, s.order_date, m.product_name, ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS x
    FROM sales AS s
    LEFT JOIN members AS mem
    ON s.customer_id = mem.customer_id
    LEFT JOIN menu AS m
    ON s.product_id = m.product_id
    WHERE s.order_date < mem.join_date
)

SELECT customer_id, product_name
FROM non_member_purchases
WHERE x = 1;

-- What is the total items and amount spent for each member before they became a member?
SELECT s.customer_id, COUNT(s.customer_id) AS items, SUM(m.price) AS spent
FROM sales AS s
LEFT JOIN members AS mem
ON s.customer_id = mem.customer_id
LEFT JOIN menu AS m
ON s.product_id = m.product_id
WHERE s.order_date < mem.join_date
GROUP BY s.customer_id;

-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH total_points AS (
	SELECT s.customer_id, m.product_id, m.price
	FROM sales AS s
	LEFT JOIN menu AS m
	ON s.product_id = m.product_id
)

SELECT customer_id,
	SUM(
		CASE
			WHEN product_id = 1 THEN price*20
			ELSE price*10
        END
    ) as total_points
FROM total_points
GROUP BY customer_id;
    
-- In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - 
-- how many points do customer A and B have at the end of January?
WITH total_points AS (
	SELECT s.customer_id, m.product_id, m.price, mem.join_date, mem.join_date + 6 AS first_week, s.order_date
	FROM sales AS s
	LEFT JOIN menu AS m
	ON s.product_id = m.product_id
    LEFT JOIN members AS mem
	ON s.customer_id = mem.customer_id
)

SELECT customer_id,
	SUM(
		CASE
			WHEN product_id = 1 THEN price*20
            WHEN order_date BETWEEN join_date AND first_week THEN price*20
			ELSE price*10
        END
    ) as total_points
FROM total_points
WHERE order_date <= '2021-01-31'
GROUP BY customer_id;

-- Join All The Things
WITH all_things AS (
	SELECT s.customer_id, s.order_date, m.product_name, m.price, 	
		(CASE
			WHEN mem.join_date <= s.order_date THEN "Y"
			ELSE "N"
		END) AS member    
	FROM sales AS s
	LEFT JOIN members AS mem
	ON s.customer_id = mem.customer_id
	LEFT JOIN menu AS m
	ON s.product_id = m.product_id
)

SELECT * FROM all_things;

-- Rank All The Things
WITH all_things AS (
	SELECT s.customer_id, s.order_date, m.product_name, m.price, 	
		(CASE
			WHEN mem.join_date <= s.order_date THEN "Y"
			ELSE "N"
		END) AS member    
	FROM sales AS s
	LEFT JOIN members AS mem
	ON s.customer_id = mem.customer_id
	LEFT JOIN menu AS m
	ON s.product_id = m.product_id
)

SELECT *,
    (CASE
		WHEN member = "Y" THEN DENSE_RANK() OVER (PARTITION BY customer_id, member ORDER BY order_date)
        ELSE "null"
    END) AS ranking
FROM all_things; 
  