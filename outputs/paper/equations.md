---
title: Equations
---

EQ_MINCER_BASE

$$\ln w_i = \alpha_0 + \beta\,\mathrm{educ}_i + \gamma_1\,\mathrm{exp}_i + \gamma_2\,\mathrm{exp}_i^2 + \varepsilon_i$$

EQ_MINCER_EXTENDED

$$\ln w_i = \alpha_0 + \beta\,\mathrm{educ}_i + \gamma_1\,\mathrm{exp}_i + \gamma_2\,\mathrm{exp}_i^2 + \mathbf{X}_i'\boldsymbol{\delta} + \mu_a + \tau_t + \varepsilon_i$$

EQ_FE_PANEL

$$\overline{\ln w}_{cat} = \mu_0 + \mu_1\,\overline{\mathrm{educ}}_{cat} + \mu_2\,\overline{\mathrm{exp}}_{cat} + \mu_3\,\overline{\mathrm{exp}}_{cat}^2 + \overline{\mathbf{X}}_{cat}'\boldsymbol{\phi} + \alpha_{ca} + \tau_t + u_{cat}$$

EQ_HAUSMAN

$$H = (\hat\beta_{FE} - \hat\beta_{RE})'\,[V(\hat\beta_{FE}) - V(\hat\beta_{RE})]^{-1}\,(\hat\beta_{FE} - \hat\beta_{RE})$$

EQ_IV_STAGE1

$$\mathrm{educ}_i = \pi_0 + \pi_1\,Z_i + \mathbf{X}_i'\boldsymbol{\pi}_2 + \mu_a + \tau_t + \eta_i$$

EQ_IV_STAGE2

$$\ln w_i = \beta_0 + \beta\,\widehat{\mathrm{educ}}_i + \mathbf{X}_i'\boldsymbol{\beta}_2 + \mu_a + \tau_t + u_i$$

EQ_IVTR

$$\ln w_i = \begin{cases} \beta_{1,0} + \beta_{1,1}\,\mathrm{educ}_i + \mathbf{X}_i'\boldsymbol{\beta}_{1,2} + u_i, & q_i \le \gamma \\[2pt] \beta_{2,0} + \beta_{2,1}\,\mathrm{educ}_i + \mathbf{X}_i'\boldsymbol{\beta}_{2,2} + u_i, & q_i > \gamma \end{cases}$$

EQ_SUPWALD

$$\mathrm{SupWald} = \sup_{\gamma \in \Gamma} \frac{n\,[\mathrm{SSR}_0 - \mathrm{SSR}(\gamma)]}{\mathrm{SSR}(\gamma)}$$

EQ_RATIO

$$\mathrm{ratio}_{s,y} = \frac{\mathrm{teachers}_{s,y}}{\mathrm{students}_{s,y}}$$
