USE [Company_Reports]
GO
/****** Object:  StoredProcedure [dbo].[sp_Project_Profitability]    Script Date: 2/22/2022 2:57:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


Create Procedure [dbo].[sp_Project_Profitability]
(
	@CostCode varchar(MAX) = null
)
as
BEGIN

if @CostCode is null
	BEGIN
	Select @CostCode = STUFF(
                        (   SELECT ',' + CONVERT(NVARCHAR(50), CostCode) 
                            FROM CostCode                            
                            FOR xml path('')
                        )
                        , 1
                        , 1
                        , '')
	END

SELECT Proj.CompanyCode
 , Proj.CompanyName
 , Proj.ProjectNumber
 , ProjectName = Proj.[Description]
 , ProjectStatus = Proj.[Status]
 , ClosedTgtGrossProfitPct = CASE WHEN IsNull(ProjProfit.ClosedSales, 0) <> 0
  THEN ProjProfit.ClosedTgtGrossProfit / ProjProfit.ClosedSales
  ELSE NULL END 
 , ClosedGrossProfitPct = CASE WHEN IsNull(ProjProfit.ClosedSales, 0) <> 0
  THEN ProjProfit.ClosedGrossProfit / ProjProfit.ClosedSales ELSE NULL END 
 , ProjProfit.ClosedSales
 , ProjProfit.ClosedTgtGrossProfit
 , ProjProfit.ClosedGrossProfit  
 , IncidentNumber
 , [Event Status]
 , CostCode
FROM dbo.Project AS Proj WITH (NOLOCK)

/* Project Profitability Statistics */
LEFT JOIN ( SELECT	InvDet.ProjectNumber
			, AllTaskZeroCosts = InvDet.TaskZeroCosts
			, ClosedCosts = CASE WHEN Evnt.[Status] = 'Closed' THEN InvDet.Costs When pt.TaskNumber = 0 Then InvDet.Costs ELSE 0 END
			, ClosedSales = CASE WHEN Evnt.[Status] = 'Closed' THEN InvDet.Sales When pt.TaskNumber = 0 Then InvDet.Sales ELSE 0 END
			, ClosedGross = CASE WHEN Evnt.[Status] = 'Closed' THEN InvDet.Gross When pt.TaskNumber = 0 Then InvDet.Gross ELSE 0 END
			, ClosedGrossProfit = CASE WHEN Evnt.[Status] = 'Closed' THEN InvDet.Sales
				- CASE WHEN CostCode.UserText3 = 'True'
					THEN 0 ELSE InvDet.Costs END ELSE 0 END
			, ClosedTgtGrossProfit = (IsNull(CodePM.TargetGrossProfitPercent, 0) / 100) * 
				(CASE WHEN Evnt.[Status] = 'Closed' THEN InvDet.Sales ELSE 0 END)
			, Evnt.IncidentNumber
			, Evnt.Status as [Event Status]
			, CostCode.CostCode
		FROM (	SELECT	Invoice.ProjectNumber
				, Invoice.IncidentNumber
				, Invoice.CostCode
				, isnull(inc.ProjectTaskID,Invoice.TaskID) as TaskID
				, Sum(Invoice.CostAmount) AS Costs
				, Sum(Invoice.SalesAmount) AS Sales
				, SUM(Case When CostCode.UserText3 = 'True' Then 0 Else Invoice.CostAmount END) as Gross
				, Sum(CASE WHEN ProjSite.TaskNumber = 0
					THEN Invoice.CostAmount ELSE 0 END) AS TaskZeroCosts
			FROM	Invoice WITH (NOLOCK)
			LEFT JOIN Event inc 
				on Invoice.IncidentNumber = inc.IncidentNumber
			LEFT JOIN ProjectTask AS ProjSite WITH (NOLOCK)
				ON	isnull(inc.ProjectTaskID,Invoice.TaskID) = ProjSite.ID
			JOIN CostCode on Invoice.CostCode = CostCode.CostCode
			WHERE	Invoice.CostCode In (Select Value From dbo.fn_BW_SplitParam(@CostCode,','))
			GROUP BY Invoice.ProjectNumber, Invoice.IncidentNumber
				, Invoice.CostCode, isnull(inc.ProjectTaskID,Invoice.TaskID)
				) AS InvDet
		    LEFT JOIN CostCode WITH (NOLOCK)
			ON InvDet.CostCode = CostCode.CostCode
		    LEFT JOIN Event AS Evnt WITH (NOLOCK)
			ON	InvDet.IncidentNumber = Evnt.IncidentNumber
		    LEFT JOIN IncidentProfitMarginByCostCode AS CodePM WITH (NOLOCK)
			ON	Evnt.TemplateIncidentNumber = CodePM.IncidentNumber
			AND	InvDet.CostCode = CodePM.CostCode
		    LEFT JOIN ProjectTask pt WITH (NOLOCK)
			on InvDet.TaskID = pt.ID
		) AS ProjProfit
ON Proj.ProjectNumber = ProjProfit.ProjectNumber
Where Case When proj.ProjectNumber LIKE '*%' Then 'Pre-Sales' When proj.ProjectType = 'Internal' and proj.ProjectNumber NOT LIKE '*%' Then 'Internal' Else 'Customer' END = 'Customer'
ORDER BY ProjectNumber;

END

