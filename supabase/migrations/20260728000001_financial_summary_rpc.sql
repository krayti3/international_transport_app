CREATE OR REPLACE FUNCTION get_financial_summary(
    p_start_date DATE,
    p_end_date     DATE
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_revenue  NUMERIC := 0;
    v_total_expenses NUMERIC := 0;
BEGIN
    -- الإيرادات (capital_injection + trip_revenue)
    SELECT COALESCE(SUM(amount), 0)
      INTO v_total_revenue
      FROM treasury_transactions
     WHERE type IN ('capital_injection', 'trip_revenue')
       AND created_at::date BETWEEN p_start_date AND p_end_date;

    -- المصروفات (كل ما عدا الإيرادات)
    SELECT COALESCE(SUM(amount), 0)
      INTO v_total_expenses
      FROM treasury_transactions
     WHERE type NOT IN ('capital_injection', 'trip_revenue')
       AND created_at::date BETWEEN p_start_date AND p_end_date;

    RETURN json_build_object(
      'total_revenue',  v_total_revenue,
      'total_expenses', v_total_expenses,
      'net_profit',     v_total_revenue - v_total_expenses
    );
END;
$$;
