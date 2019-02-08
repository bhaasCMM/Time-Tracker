USE SANDBOX

CREATE TABLE users (
user_id INT NOT NULL IDENTITY(1,1) CONSTRAINT PK_users_userid PRIMARY KEY,
username VARCHAR(100) NOT NULL CONSTRAINT UQ_users_username UNIQUE,
first_name VARCHAR(100),
last_name VARCHAR(100),
created_dt DATETIME NOT NULL CONSTRAINT DF_users_createddt_getdate DEFAULT GETDATE()
)

CREATE TABLE activity (
activity VARCHAR(100) NOT NULL CONSTRAINT PK_activity_activity PRIMARY KEY)
INSERT activity (activity) VALUES ('General'),('Coding'),('Machine Work')

CREATE TABLE user_activity(
user_activity_id INT NOT NULL IDENTITY(1,1) CONSTRAINT PK_useractivity_useractivityid PRIMARY KEY,
user_id INT NOT NULL CONSTRAINT FK_useractivity_userid REFERENCES users(user_id),
activity VARCHAR(100) NOT NULL CONSTRAINT FK_useractivity_activity REFERENCES activity(activity) CONSTRAINT DF_useractivity_activity_general DEFAULT 'General',
login_dt DATETIME NOT NULL CONSTRAINT DF_useractivity_logindt_getdate DEFAULT GETDATE(),
logout_dt DATETIME
)
-------------------------------
GO

-------------------------------
CREATE OR ALTER PROCEDURE user_create
@username VARCHAR(100),
@first_name VARCHAR(100)=NULL,
@last_name VARCHAR(100)=NULL
AS
BEGIN
DECLARE @err VARCHAR(MAX), @user_id INT
BEGIN TRY

IF EXISTS (SELECT username FROM users WHERE username = @username)
RAISERROR('Username already exists',16,1)

   INSERT users (username, first_name, last_name)
   VALUES (@username, @first_name, @last_name)     


END TRY
BEGIN CATCH
SELECT @err = ERROR_MESSAGE()
RAISERROR(@err,16,1)
END CATCH
END
-------------------------------
GO

-------------------------------
CREATE OR ALTER PROCEDURE username_validate
@username VARCHAR(100),
@user_id INT OUTPUT
AS
BEGIN 
   SELECT @user_id = user_id  
     FROM users 
    WHERE username = @username

IF @user_id IS NULL 
RAISERROR('Invalid Username',16,1)
END
-------------------------------
GO

-------------------------------
CREATE OR ALTER PROCEDURE log_in 
@username VARCHAR(100),
@activity VARCHAR(100) = 'General',
@dt DATETIME = NULL
AS
BEGIN
DECLARE @err VARCHAR(MAX), @user_id INT
BEGIN TRY

EXEC username_validate @username, @user_id OUTPUT

IF EXISTS (SELECT user_activity_id FROM user_activity WHERE user_id = @user_id AND logout_dt IS NULL)
RAISERROR('User is still logged in to another activity.  Please log out first.',16,1)

IF NOT EXISTS (SELECT activity FROM activity WHERE activity = @activity)
RAISERROR('Invalid Activity',16,1)

   INSERT user_activity 
          (user_id, activity, login_dt)
   SELECT @user_id, @activity, ISNULL(@dt, GETDATE())

END TRY
BEGIN CATCH
SELECT @err = ERROR_MESSAGE()
RAISERROR(@err,16,1)
END CATCH
END
-------------------------------
GO

-------------------------------
CREATE OR ALTER PROCEDURE log_out
@username VARCHAR(100),
@dt DATETIME = NULL
AS
BEGIN
DECLARE @err VARCHAR(MAX), @user_id INT
BEGIN TRY
EXEC username_validate @username, @user_id OUTPUT

SET @dt = ISNULL(@dt,GETDATE())

IF NOT EXISTS (SELECT user_activity_id FROM user_activity WHERE user_id = @user_id AND logout_dt IS NULL)
RAISERROR('User is not logged in',16,1)

IF EXISTS (SELECT user_activity_id FROM  user_activity WHERE user_id = @user_id AND logout_dt IS NULL AND login_dt > @dt)
RAISERROR('Log out time cannot precede the log in time',16,1)

   UPDATE user_activity 
      SET logout_dt = @dt
    WHERE user_id = @user_id 
      AND logout_dt IS NULL

END TRY
BEGIN CATCH
SELECT @err = ERROR_MESSAGE()
RAISERROR(@err,16,1)
END CATCH
END
-------------------------------
GO

-------------------------------
CREATE OR ALTER VIEW vw_user_activity_summary
AS

   SELECT u.user_id,
          u.username,
          u.first_name,
          u.last_name,
          ua.activity,
          SUM(CAST(DATEDIFF(second,login_dt,logout_dt) AS NUMERIC(9,4))/3600.) as hrs
     FROM users u
LEFT JOIN user_activity ua
       ON u.user_id = ua.user_id
LEFT JOIN activity a
       ON ua.activity = a.activity
 GROUP BY u.user_id,
          u.username,
          u.first_name,
          u.last_name,
          ua.activity
-------------------------------
GO

